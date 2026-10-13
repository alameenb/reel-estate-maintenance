#!/usr/bin/env python3
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from flowgen import *
OUT = pathlib.Path(__file__).resolve().parent.parent / "force-app/main/default/flows"
OUT.mkdir(parents=True, exist_ok=True)
RT = "{!$Record.RecordType.DeveloperName} = 'Maintenance_Request'"
def write(api, d): (OUT / f"{api}.flow-meta.xml").write_text(flow(d))

def recstart(trigger, record_trigger, connector=None, formula=RT, scheduled=None, changed=False):
    d = {"locationX": 0, "locationY": 0, "object": "Case", "recordTriggerType": record_trigger, "triggerType": trigger, "filterFormula": formula}
    if connector: d["connector"] = to(connector)
    if scheduled: d["scheduledPaths"] = scheduled
    if changed: d["doesRequireRecordChangedToMeetCriteria"] = True
    return d
def get_case(name="Get_Case", id_ref="recordId", nxt=None, fault=None):
    d = node(name, "Get Case", assignNullValuesIfNoRecordsFound=False, filterLogic="and",
             filters=filt("Id", "EqualTo", ref(id_ref)), getFirstRecordOnly=True, object="Case", storeOutputAutomatically=True)
    if nxt: d["connector"] = to(nxt)
    if fault: d["faultConnector"] = to(fault)
    return d

# ---- CMP-030 before-save escalation stamp
write("Maintenance_Request_Before_Save", {
    "label": "Maintenance Request - Before Save", "interviewLabel": "Maintenance Request Before Save {!$Flow.CurrentDateTime}",
    "description": "CMP-030. Stamps Escalation_Due__c = now + Request_Setting__mdt.Default.Escalation_Days__c on create.",
    "processType": "AutoLaunchedFlow",
    "start": recstart("RecordBeforeSave", "Create", "Get_Record_Type", formula="NOT(ISBLANK({!$Record.RecordTypeId}))"),
    "recordLookups": [
        node("Get_Record_Type", "Get Maintenance record type", assignNullValuesIfNoRecordsFound=False, connector=to("Get_Setting"), filterLogic="and",
             filters=[filt("SobjectType", "EqualTo", s("Case")), filt("DeveloperName", "EqualTo", s("Maintenance_Request"))], getFirstRecordOnly=True, object="RecordType", storeOutputAutomatically=True),
        node("Get_Setting", "Get Request Setting", assignNullValuesIfNoRecordsFound=False, connector=to("Has_Setting"),
             filterLogic="and", filters=filt("DeveloperName", "EqualTo", s("Default")), getFirstRecordOnly=True, object="Request_Setting__mdt", storeOutputAutomatically=True)],
    "decisions": node("Has_Setting", "Maintenance request with a setting?", defaultConnectorLabel="No",
        rules={"name": "Setting_Found", "conditionLogic": "and", "conditions": [cond("Get_Setting", "IsNull", b(False)), cond("$Record.RecordTypeId", "EqualTo", ref("Get_Record_Type.Id"))],
               "connector": to("Set_Escalation_Due"), "label": "Yes"}),
    "assignments": node("Set_Escalation_Due", "Set Escalation Due", assignmentItems=item("$Record.Escalation_Due__c", ref("EscalationDue"))),
    "formulas": formula("EscalationDue", "DateTime", "{!$Flow.CurrentDateTime} + {!Get_Setting.Escalation_Days__c}"),
})

# ---- CMP-031 escalation scheduled path
write("Maintenance_Request_Escalation", {
    "label": "Maintenance Request - Escalation", "interviewLabel": "Maintenance Request Escalation {!$Flow.CurrentDateTime}",
    "description": "CMP-031. At Escalation_Due__c, moves unresolved requests to the Maintenance Escalation queue and flags them.",
    "processType": "AutoLaunchedFlow", "runInMode": "SystemModeWithoutSharing",
    "start": recstart("RecordAfterSave", "CreateAndUpdate", formula=RT + " && NOT(ISBLANK({!$Record.Escalation_Due__c}))", changed=True,
        scheduled={"name": "Escalate", "connector": to("Get_Current_Case"), "label": "Escalate", "offsetNumber": 0, "offsetUnit": "Hours",
                   "recordField": "Escalation_Due__c", "timeSource": "RecordField"}),
    "recordLookups": [
        get_case("Get_Current_Case", "$Record.Id", "Still_Unresolved"),
        node("Get_Escalation_Queue", "Get Escalation Queue", assignNullValuesIfNoRecordsFound=False, connector=to("Escalate_Case"), filterLogic="and",
             filters=[filt("Type", "EqualTo", s("Queue")), filt("DeveloperName", "EqualTo", s("Maintenance_Escalation"))],
             getFirstRecordOnly=True, object="Group", storeOutputAutomatically=True)],
    "decisions": node("Still_Unresolved", "Still unresolved?", defaultConnectorLabel="Resolved or already escalated",
        rules={"name": "Escalate_It", "conditionLogic": "and", "conditions": [
            cond("Get_Current_Case.Status", "NotEqualTo", s("Resolved")), cond("Get_Current_Case.Status", "NotEqualTo", s("Closed")),
            cond("Get_Current_Case.Is_Escalated__c", "EqualTo", b(False))], "connector": to("Get_Escalation_Queue"), "label": "Escalate"}),
    "recordUpdates": node("Escalate_Case", "Escalate Case", filterLogic="and", filters=filt("Id", "EqualTo", ref("Get_Current_Case.Id")),
        inputAssignments=[assign("OwnerId", ref("Get_Escalation_Queue.Id")), assign("Is_Escalated__c", b(True))], object="Case"),
})

# ---- CMP-050 notification dispatcher
def notify_call(name, ev):
    return node(name, f"Notify {ev}", actionName="MaintenanceNotificationService", actionType="apex", flowTransactionModel="CurrentTransaction",
                inputParameters=[{"name": "caseId", "value": ref("$Record.Id")}, {"name": "eventName", "value": s(ev)}])
write("Maintenance_Request_Notifications", {
    "label": "Maintenance Request - Notifications", "interviewLabel": "Maintenance Request Notifications {!$Flow.CurrentDateTime}",
    "description": "CMP-050. Raises Submitted, Status_Changed or Appointment_Set; the rules live in Notification_Rule__mdt.",
    "processType": "AutoLaunchedFlow",
    "start": recstart("RecordAfterSave", "CreateAndUpdate", "Which_Event"),
    "formulas": [formula("IsNew", "Boolean", "ISNEW()")],
    "decisions": node("Which_Event", "Which event?", defaultConnectorLabel="No customer event", rules=[
        {"name": "Submitted", "conditionLogic": "and", "conditions": cond("IsNew", "EqualTo", b(True)), "connector": to("Notify_Submitted"), "label": "Submitted"},
        {"name": "Status_Changed", "conditionLogic": "and", "conditions": cond("$Record.Status", "IsChanged", b(True)), "connector": to("Notify_Status_Changed"), "label": "Status changed"},
        {"name": "Appointment_Set", "conditionLogic": "and", "conditions": [cond("$Record.Appointment_DateTime__c", "IsChanged", b(True)), cond("$Record.Appointment_DateTime__c", "IsNull", b(False))],
         "connector": to("Notify_Appointment_Set"), "label": "Appointment set"}]),
    "actionCalls": [notify_call("Notify_Submitted", "Submitted"), notify_call("Notify_Status_Changed", "Status_Changed"), notify_call("Notify_Appointment_Set", "Appointment_Set")],
})

# ---- CMP-059 reminder subflow (autolaunched)
write("Maintenance_Send_Reminder_Action", {
    "label": "Maintenance - Send Reminder (Action)", "interviewLabel": "Send Reminder Action {!$Flow.CurrentDateTime}",
    "description": "CMP-059. Emails and notifies the customer about outstanding information and logs a completed Task.",
    "processType": "AutoLaunchedFlow", "runInMode": "SystemModeWithSharing",
    "start": {"locationX": 0, "locationY": 0, "connector": to("Send_Message")},
    "actionCalls": node("Send_Message", "Send reminder to customer", actionName="MaintenanceCustomerMessageAction", actionType="apex",
        connector=to("Was_Sent"), flowTransactionModel="CurrentTransaction",
        inputParameters=[{"name": "caseId", "value": ref("recordId")}, {"name": "templateName", "value": s("Maintenance_Information_Reminder")},
                         {"name": "note", "value": ref("reminderNote")}, {"name": "notificationTitle", "value": s("Reminder: information needed for request")}],
        outputParameters=[{"assignToReference": "notificationSent", "name": "notificationSent"}, {"assignToReference": "emailSent", "name": "emailSent"},
                          {"assignToReference": "errorMessage", "name": "errorMessage"}], storeOutputAutomatically=False),
    "decisions": node("Was_Sent", "Was the email sent?", defaultConnectorLabel="Not sent",
        rules={"name": "Sent", "conditionLogic": "and", "conditions": cond("emailSent", "EqualTo", b(True)), "connector": to("Get_Case"), "label": "Sent"}),
    "recordLookups": get_case("Get_Case", "recordId", "Log_Task"),
    "recordCreates": node("Log_Task", "Log reminder task", inputAssignments=[
        assign("WhatId", ref("recordId")), assign("WhoId", ref("Get_Case.ContactId")), assign("Subject", s("Reminder sent: outstanding information")),
        assign("Status", s("Completed")), assign("ActivityDate", ref("$Flow.CurrentDate")), assign("Description", ref("reminderNote"))],
        object="Task", storeOutputAutomatically=True),
    "variables": [var("recordId", "String", inp=True), var("reminderNote", "String", inp=True), var("notificationSent", "Boolean", out=True, value=b(False)),
                  var("emailSent", "Boolean", value=b(False)), var("errorMessage", "String", out=True)],
})

# ---- generic screen-flow wrapper for an action subflow
def screen(name, label, fields, nxt=None, finish=True):
    d = node(name, label, allowBack=False, allowFinish=finish, allowPause=False, fields=fields, showFooter=True, showHeader=True)
    if nxt: d["connector"] = to(nxt)
    return d
def text(name, html): return {"name": name, "fieldText": html, "fieldType": "DisplayText"}

# ---- CMP-060 reminder screen flow
write("Maintenance_Send_Reminder", {
    "label": "Send Reminder", "interviewLabel": "Send Reminder {!$Flow.CurrentDateTime}",
    "description": "CMP-060. Quick action: confirm and send a reminder for outstanding customer information.",
    "processType": "Flow",
    "start": {"locationX": 0, "locationY": 0, "connector": to("Get_Case")},
    "recordLookups": get_case("Get_Case", "recordId", "Is_Awaiting"),
    "decisions": node("Is_Awaiting", "Awaiting customer information?", defaultConnector=to("Not_Awaiting"), defaultConnectorLabel="No",
        rules={"name": "Awaiting", "conditionLogic": "and", "conditions": cond("Get_Case.Status", "EqualTo", s("Awaiting Customer Information")), "connector": to("Confirm"), "label": "Yes"}),
    "screens": [
        screen("Not_Awaiting", "Cannot send", text("Not_Awaiting_Text", "<p>A reminder can only be sent while waiting for customer information.</p>")),
        screen("Confirm", "Send reminder", [
            text("Confirm_Text", "<p>Send a reminder to <strong>{!Get_Case.Contact.Name}</strong> ({!Get_Case.Contact.Email}) about request <strong>{!Get_Case.CaseNumber}</strong>?</p>"),
            {"name": "Reminder_Note", "dataType": "String", "fieldText": "Reminder note (optional, the customer will see this)", "fieldType": "LargeTextArea", "isRequired": False}],
            nxt="Run_Reminder"),
        screen("Done", "Reminder sent", text("Done_Text", "<p>{!ResultText}</p>"))],
    "subflows": node("Run_Reminder", "Send reminder", connector=to("Done"), flowName="Maintenance_Send_Reminder_Action",
        inputAssignments=[{"name": "recordId", "value": ref("recordId")}, {"name": "reminderNote", "value": ref("Reminder_Note")}],
        outputAssignments=[{"assignToReference": "notificationSent", "name": "notificationSent"}, {"assignToReference": "errorMessage", "name": "errorMessage"}]),
    "formulas": formula("ResultText", "String", "IF(NOT(ISBLANK({!errorMessage})), 'The reminder was not sent: ' & {!errorMessage}, 'An email reminder was sent' & IF({!notificationSent}, ' and a portal notification was sent.', '. The customer has no portal login, so no portal notification was sent.'))"),
    "variables": [var("recordId", "String", inp=True), var("notificationSent", "Boolean", value=b(False)), var("errorMessage", "String")],
})

# ---- CMP-109 information request action + CMP-110 screen
write("Maintenance_Request_Information_Action", {
    "label": "Maintenance - Request Information (Action)", "interviewLabel": "Request Information Action {!$Flow.CurrentDateTime}",
    "description": "CMP-109. Posts a customer-visible information request on the case feed (the feed trigger emails and notifies the customer).",
    "processType": "AutoLaunchedFlow", "runInMode": "SystemModeWithSharing",
    "start": {"locationX": 0, "locationY": 0, "connector": to("Get_Case")},
    "recordLookups": get_case("Get_Case", "recordId", "Is_Valid"),
    "decisions": node("Is_Valid", "Can request information?", defaultConnector=to("Set_Invalid"), defaultConnectorLabel="No",
        rules={"name": "Valid", "conditionLogic": "and", "conditions": [
            cond("Get_Case", "IsNull", b(False)), cond("Get_Case.RecordType.DeveloperName", "EqualTo", s("Maintenance_Request")),
            cond("Get_Case.ContactId", "IsNull", b(False)), cond("Get_Case.Status", "NotEqualTo", s("Closed"))], "connector": to("Post_Request"), "label": "Yes"}),
    "recordCreates": node("Post_Request", "Post information request", connector=to("Set_Success"), faultConnector=to("Set_Fault"),
        inputAssignments=[assign("ParentId", ref("recordId")), assign("Type", s("TextPost")), assign("Visibility", s("AllUsers")), assign("Body", ref("PostBody"))],
        object="FeedItem", storeOutputAutomatically=True),
    "assignments": [
        node("Set_Success", "Set success", assignmentItems=item("success", b(True))),
        node("Set_Invalid", "Set invalid", assignmentItems=item("errorMessage", s("Information can only be requested on an open maintenance request that has a customer contact."))),
        node("Set_Fault", "Set fault", assignmentItems=item("errorMessage", ref("$Flow.FaultMessage")))],
    "formulas": formula("PostBody", "String", "'Information requested: ' & {!informationRequest}"),
    "variables": [var("recordId", "String", inp=True), var("informationRequest", "String", inp=True), var("success", "Boolean", out=True, value=b(False)), var("errorMessage", "String", out=True)],
})
def wrapper(api, label, desc, subflow, ask_fields, sub_inputs, intro_label):
    write(api, {
        "label": label, "interviewLabel": label + " {!$Flow.CurrentDateTime}", "description": desc, "processType": "Flow",
        "start": {"locationX": 0, "locationY": 0, "connector": to("Ask")},
        "screens": [screen("Ask", intro_label, ask_fields, nxt="Run_Action"),
                    screen("Result", "Result", text("Result_Text", "<p>{!ResultText}</p>"))],
        "subflows": node("Run_Action", label, connector=to("Result"), flowName=subflow,
            inputAssignments=sub_inputs, outputAssignments=[{"assignToReference": "success", "name": "success"}, {"assignToReference": "errorMessage", "name": "errorMessage"}]),
        "formulas": formula("ResultText", "String", "IF({!success}, 'Done. The customer has been notified by email and in the portal.', 'Not completed: ' & {!errorMessage})"),
        "variables": [var("recordId", "String", inp=True), var("success", "Boolean", value=b(False)), var("errorMessage", "String")],
    })
wrapper("Maintenance_Request_Information", "Request Information", "CMP-110. Quick action: ask the customer for more information.",
        "Maintenance_Request_Information_Action",
        [{"name": "Information_Request", "dataType": "String", "fieldText": "What information do you need from the customer?", "fieldType": "LargeTextArea",
          "helpText": "The customer will see this message in the portal and by email.", "isRequired": True}],
        [{"name": "recordId", "value": ref("recordId")}, {"name": "informationRequest", "value": ref("Information_Request")}], "Request information")

# ---- CMP-112 confirm resolution action + CMP-113 screen
write("Maintenance_Confirm_Resolution_Action", {
    "label": "Maintenance - Confirm Resolution (Action)", "interviewLabel": "Confirm Resolution Action {!$Flow.CurrentDateTime}",
    "description": "CMP-112. Sets Status = Resolved (which notifies the customer) and records an internal feed note.",
    "processType": "AutoLaunchedFlow", "runInMode": "SystemModeWithSharing",
    "start": {"locationX": 0, "locationY": 0, "connector": to("Get_Case")},
    "recordLookups": get_case("Get_Case", "recordId", "Is_Valid"),
    "decisions": node("Is_Valid", "Can resolve?", defaultConnector=to("Set_Invalid"), defaultConnectorLabel="No",
        rules={"name": "Valid", "conditionLogic": "and", "conditions": [
            cond("Get_Case", "IsNull", b(False)), cond("Get_Case.RecordType.DeveloperName", "EqualTo", s("Maintenance_Request")),
            cond("Get_Case.ContactId", "IsNull", b(False)), cond("Get_Case.Status", "NotEqualTo", s("Resolved")), cond("Get_Case.Status", "NotEqualTo", s("Closed"))],
            "connector": to("Mark_Resolved"), "label": "Yes"}),
    "recordUpdates": node("Mark_Resolved", "Mark resolved", connector=to("Log_Note"), faultConnector=to("Set_Fault"), filterLogic="and",
        filters=filt("Id", "EqualTo", ref("recordId")), inputAssignments=assign("Status", s("Resolved")), object="Case"),
    "recordCreates": node("Log_Note", "Log internal note", connector=to("Set_Success"), faultConnector=to("Set_Fault"),
        inputAssignments=[assign("ParentId", ref("recordId")), assign("Type", s("TextPost")), assign("Visibility", s("InternalUsers")), assign("Body", ref("NoteBody"))],
        object="FeedItem", storeOutputAutomatically=True),
    "assignments": [
        node("Set_Success", "Set success", assignmentItems=item("success", b(True))),
        node("Set_Invalid", "Set invalid", assignmentItems=item("errorMessage", s("Only an open maintenance request with a customer contact can be resolved."))),
        node("Set_Fault", "Set fault", assignmentItems=item("errorMessage", ref("$Flow.FaultMessage")))],
    "formulas": formula("NoteBody", "String", "'Customer informed that work is complete and asked to confirm resolution by ' & {!$User.FirstName} & ' ' & {!$User.LastName}"),
    "variables": [var("recordId", "String", inp=True), var("success", "Boolean", out=True, value=b(False)), var("errorMessage", "String", out=True)],
})
wrapper("Maintenance_Confirm_Resolution", "Confirm Resolution with Customer", "CMP-113. Quick action: mark resolved and ask the customer to confirm.",
        "Maintenance_Confirm_Resolution_Action",
        [text("Confirm_Text", "<p>Mark this request as <strong>Resolved</strong> and ask the customer to confirm the issue is resolved?</p><p>Select Next to confirm, or close this window to cancel.</p>")],
        [{"name": "recordId", "value": ref("recordId")}], "Confirm resolution")

# ---- CMP-117 portal rate request
write("Maintenance_Rate_Request", {
    "label": "Rate Your Request", "interviewLabel": "Rate Request {!$Flow.CurrentDateTime}",
    "description": "CMP-117. Portal screen flow: customer rates a resolved request 1-5.", "processType": "Flow",
    "start": {"locationX": 0, "locationY": 0, "connector": to("Get_Case")},
    "recordLookups": get_case("Get_Case", "recordId", "Can_Rate"),
    "decisions": node("Can_Rate", "Can rate?", defaultConnector=to("Cannot_Rate"), defaultConnectorLabel="No",
        rules={"name": "Eligible", "conditionLogic": "and", "conditions": [cond("Get_Case.Status", "EqualTo", s("Resolved")), cond("Get_Case.Satisfaction_Rating__c", "IsNull", b(True))],
               "connector": to("Rate"), "label": "Yes"}),
    "choices": [{"name": f"R{i}", "choiceText": t, "dataType": "Number", "value": n(i)} for i, t in
                [(5, "5 - Very satisfied"), (4, "4 - Satisfied"), (3, "3 - Neutral, issue resolved"), (2, "2 - Dissatisfied, issue not fully resolved"), (1, "1 - Very dissatisfied, issue not resolved")]],
    "screens": [
        screen("Cannot_Rate", "Rating unavailable", text("Cannot_Text", "<p>This request can be rated once it is resolved, and only once.</p>")),
        screen("Rate", "Rate your request", [
            text("Rate_Intro", "<p>Request <strong>{!Get_Case.CaseNumber}</strong>: {!Get_Case.Subject}</p>"),
            {"name": "Rating", "choiceReferences": ["R5", "R4", "R3", "R2", "R1"], "dataType": "Number",
             "fieldText": "Is your issue resolved, and how satisfied are you?", "fieldType": "RadioButtons", "isRequired": True, "scale": 0}],
            nxt="Save_Rating"),
        screen("Thanks", "Thank you", text("Thanks_Text", "<p>Thank you for your feedback.</p>")),
        screen("Error", "Something went wrong", text("Error_Text", "<p>Your rating could not be saved: {!$Flow.FaultMessage}</p>"))],
    "recordUpdates": node("Save_Rating", "Save rating", connector=to("Thanks"), faultConnector=to("Error"), filterLogic="and",
        filters=filt("Id", "EqualTo", ref("recordId")), inputAssignments=assign("Satisfaction_Rating__c", ref("Rating")), object="Case"),
    "variables": [var("recordId", "String", inp=True)],
})

# ---- CMP-118 rating handler
write("Maintenance_Request_Rating_Handler", {
    "label": "Maintenance Request - Rating Handler", "interviewLabel": "Rating Handler {!$Flow.CurrentDateTime}",
    "description": "CMP-118. Rating 3-5 stamps the response date; 1-2 closes the case and opens a linked follow-up request.",
    "processType": "AutoLaunchedFlow", "runInMode": "SystemModeWithoutSharing",
    "start": recstart("RecordAfterSave", "Update", "Is_Satisfied",
        formula=RT + " && ISCHANGED({!$Record.Satisfaction_Rating__c}) && NOT(ISBLANK({!$Record.Satisfaction_Rating__c})) && TEXT(PRIORVALUE({!$Record.Status})) = 'Resolved'"),
    "decisions": node("Is_Satisfied", "Rating 3 or more?", defaultConnector=to("Close_Parent"), defaultConnectorLabel="1 or 2",
        rules={"name": "Satisfied", "conditionLogic": "and", "conditions": cond("$Record.Satisfaction_Rating__c", "GreaterThanOrEqualTo", n(3)),
               "connector": to("Stamp_Response"), "label": "3 to 5"}),
    "recordUpdates": [
        node("Stamp_Response", "Stamp response date", filterLogic="and", filters=filt("Id", "EqualTo", ref("$Record.Id")),
             inputAssignments=assign("Satisfaction_Response_Date__c", ref("$Flow.CurrentDateTime")), object="Case"),
        node("Close_Parent", "Close parent", connector=to("Get_Record_Type"), filterLogic="and", filters=filt("Id", "EqualTo", ref("$Record.Id")),
             inputAssignments=[assign("Status", s("Closed")), assign("Satisfaction_Response_Date__c", ref("$Flow.CurrentDateTime"))], object="Case")],
    "recordLookups": [
        node("Get_Record_Type", "Get record type", assignNullValuesIfNoRecordsFound=False, connector=to("Get_Intake_Queue"), filterLogic="and",
             filters=[filt("SobjectType", "EqualTo", s("Case")), filt("DeveloperName", "EqualTo", s("Maintenance_Request"))], getFirstRecordOnly=True, object="RecordType", storeOutputAutomatically=True),
        node("Get_Intake_Queue", "Get intake queue", assignNullValuesIfNoRecordsFound=False, connector=to("Create_Follow_Up"), filterLogic="and",
             filters=[filt("Type", "EqualTo", s("Queue")), filt("DeveloperName", "EqualTo", s("Maintenance_Requests"))], getFirstRecordOnly=True, object="Group", storeOutputAutomatically=True)],
    "recordCreates": [
        node("Create_Follow_Up", "Create follow-up request", assignRecordIdToReference="childId", connector=to("Note_On_Parent"), inputAssignments=[
            assign("RecordTypeId", ref("Get_Record_Type.Id")), assign("ParentId", ref("$Record.Id")), assign("ContactId", ref("$Record.ContactId")),
            assign("AccountId", ref("$Record.AccountId")), assign("Property__c", ref("$Record.Property__c")), assign("Issue_Category__c", ref("$Record.Issue_Category__c")),
            assign("Status", s("New")), assign("Origin", s("Web")), assign("OwnerId", ref("Get_Intake_Queue.Id")), assign("Subject", ref("ChildSubject")), assign("Description", ref("ChildDescription"))],
            object="Case"),
        node("Note_On_Parent", "Note on parent", connector=to("Note_On_Child"), inputAssignments=[
            assign("ParentId", ref("$Record.Id")), assign("Type", s("TextPost")), assign("Visibility", s("InternalUsers")), assign("Body", ref("ParentNote"))], object="FeedItem", storeOutputAutomatically=True),
        node("Note_On_Child", "Note on child", inputAssignments=[
            assign("ParentId", ref("childId")), assign("Type", s("TextPost")), assign("Visibility", s("InternalUsers")), assign("Body", ref("ChildNote"))], object="FeedItem", storeOutputAutomatically=True)],
    "formulas": [
        formula("ChildSubject", "String", "LEFT('Follow-up: ' & {!$Record.Subject}, 255)"),
        formula("ChildDescription", "String", "'Follow-up to request ' & {!$Record.CaseNumber} & ', rated ' & TEXT({!$Record.Satisfaction_Rating__c}) & ' by the customer.' & BR() & {!$Record.Description}"),
        formula("ParentNote", "String", "'Customer rated ' & TEXT({!$Record.Satisfaction_Rating__c}) & '. Request closed and follow-up request created.'"),
        formula("ChildNote", "String", "'Follow-up to request ' & {!$Record.CaseNumber} & ' (rated ' & TEXT({!$Record.Satisfaction_Rating__c}) & ').'")],
    "variables": [var("childId", "String")],
})

# ---- CMP-123 auto-close
write("Maintenance_Request_Auto_Close", {
    "label": "Maintenance Request - Auto Close", "interviewLabel": "Auto Close {!$Flow.CurrentDateTime}",
    "description": "CMP-123. Closes a satisfactorily rated, still-resolved request 42 days (6 weeks) after the customer's response.",
    "processType": "AutoLaunchedFlow", "runInMode": "SystemModeWithoutSharing",
    "start": recstart("RecordAfterSave", "CreateAndUpdate", changed=True,
        formula=RT + " && ISPICKVAL({!$Record.Status}, 'Resolved') && {!$Record.Satisfaction_Rating__c} >= 3 && NOT(ISBLANK({!$Record.Satisfaction_Response_Date__c}))",
        scheduled={"name": "Auto_Close_After_6_Weeks", "connector": to("Get_Current_Case"), "label": "Auto close after 6 weeks", "offsetNumber": 42,
                   "offsetUnit": "Days", "recordField": "Satisfaction_Response_Date__c", "timeSource": "RecordField"}),
    "recordLookups": get_case("Get_Current_Case", "$Record.Id", "Still_Eligible"),
    "decisions": node("Still_Eligible", "Still eligible?", defaultConnectorLabel="No",
        rules={"name": "Eligible", "conditionLogic": "and", "conditions": [cond("Get_Current_Case.Status", "EqualTo", s("Resolved")),
               cond("Get_Current_Case.Satisfaction_Rating__c", "GreaterThanOrEqualTo", n(3))], "connector": to("Close_Case"), "label": "Yes"}),
    "recordUpdates": node("Close_Case", "Close case", filterLogic="and", filters=filt("Id", "EqualTo", ref("Get_Current_Case.Id")),
        inputAssignments=assign("Status", s("Closed")), object="Case"),
})

# ---- CMP-062 link customer & property
write("Maintenance_Link_Customer_Property", {
    "label": "Link Customer & Property", "interviewLabel": "Link Customer Property {!$Flow.CurrentDateTime}",
    "description": "CMP-062. Find an existing customer and property and link them to the request.", "processType": "Flow",
    "start": {"locationX": 0, "locationY": 0, "connector": to("Search")},
    "screens": [
        screen("Search", "Find customer", [
            {"name": "Search_Email", "dataType": "String", "fieldText": "Email", "fieldType": "InputField", "isRequired": False},
            {"name": "Search_Phone", "dataType": "String", "fieldText": "Phone", "fieldType": "InputField", "isRequired": False},
            {"name": "Search_Last_Name", "dataType": "String", "fieldText": "Last name", "fieldType": "InputField", "isRequired": False},
            {"name": "Search_Postcode", "dataType": "String", "fieldText": "Property postcode (to find other properties)", "fieldType": "InputField", "isRequired": False}],
            nxt="Find_Contacts"),
        screen("No_Match", "No match", text("No_Match_Text", "<p>No matching customer was found. Creating new customers is out of scope for this action.</p>")),
        screen("Pick_Contact", "Choose customer", {"name": "Selected_Contact", "choiceReferences": "ContactChoices", "dataType": "String",
            "fieldText": "Customer", "fieldType": "RadioButtons", "isRequired": True}, nxt="Get_Selected_Contact"),
        screen("Pick_Property", "Choose property", [
            text("Property_Help", "<p>Properties already linked to this customer are listed first, then properties matching the postcode.</p>"),
            {"name": "Selected_Property", "choiceReferences": ["LinkedPropertyChoices", "PostcodePropertyChoices"], "dataType": "String",
             "fieldText": "Property", "fieldType": "RadioButtons", "isRequired": True}], nxt="Link_Case"),
        screen("Done", "Linked", text("Done_Text", "<p>The customer and property are now linked to this request.</p>"))],
    "recordLookups": [
        node("Find_Contacts", "Find contacts", assignNullValuesIfNoRecordsFound=False, connector=to("Any_Contacts"), filterLogic="or",
             filters=[filt("Email", "EqualTo", ref("Search_Email")), filt("Phone", "EqualTo", ref("Search_Phone")), filt("LastName", "EqualTo", ref("Search_Last_Name"))],
             getFirstRecordOnly=True, object="Contact", storeOutputAutomatically=True),
        node("Get_Selected_Contact", "Get selected contact", assignNullValuesIfNoRecordsFound=False, connector=to("Pick_Property"), filterLogic="and",
             filters=filt("Id", "EqualTo", ref("Selected_Contact")), getFirstRecordOnly=True, object="Contact", storeOutputAutomatically=True)],
    "decisions": node("Any_Contacts", "Any contacts?", defaultConnector=to("No_Match"), defaultConnectorLabel="None",
        rules={"name": "Found", "conditionLogic": "and", "conditions": cond("Find_Contacts", "IsNull", b(False)), "connector": to("Pick_Contact"), "label": "Found"}),
    "dynamicChoiceSets": [
        {"name": "ContactChoices", "dataType": "String", "displayField": "Name", "filterLogic": "or",
         "filters": [filt("Email", "EqualTo", ref("Search_Email")), filt("Phone", "EqualTo", ref("Search_Phone")), filt("LastName", "EqualTo", ref("Search_Last_Name"))],
         "object": "Contact", "sortField": "Name", "sortOrder": "Asc", "valueField": "Id"},
        {"name": "LinkedPropertyChoices", "dataType": "String", "displayField": "Property_Name__c", "filterLogic": "and",
         "filters": filt("Contact__c", "EqualTo", ref("Selected_Contact")), "object": "Property_Customer__c", "valueField": "Property__c"},
        {"name": "PostcodePropertyChoices", "dataType": "String", "displayField": "Name", "filterLogic": "and",
         "filters": filt("Postal_Code__c", "EqualTo", ref("Search_Postcode")), "object": "Property__c", "sortField": "Name", "sortOrder": "Asc", "valueField": "Id"}],
    "recordUpdates": node("Link_Case", "Link case", connector=to("Done"), filterLogic="and", filters=filt("Id", "EqualTo", ref("recordId")),
        inputAssignments=[assign("ContactId", ref("Selected_Contact")), assign("AccountId", ref("Get_Selected_Contact.AccountId")), assign("Property__c", ref("Selected_Property"))], object="Case"),
    "variables": [var("recordId", "String", inp=True)],
})
print("flows:", len(list(OUT.glob("*.flow-meta.xml"))))
