#!/usr/bin/env python3
"""Generate declarative metadata for the Reel Estate maintenance request solution.

Values the design marked as "to be supplied by the business" (categories, teams)
use DEMO placeholders defined below; change them here and regenerate.
"""
import pathlib, textwrap
ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "force-app/main/default"
API = "62.0"
NS = 'xmlns="http://soap.sforce.com/2006/04/metadata"'

# ---- DEMO VALUES (design TBCs) ----
CATEGORIES = [("Plumbing","Plumbing"),("Electrical","Electrical"),("Heating_Cooling","Heating & Cooling"),
              ("Appliances","Appliances"),("Structural","Structural"),("Pest_Control","Pest Control"),("General","General")]
TEAMS = [("Plumbing_Team","Plumbing Team"),("Electrical_Team","Electrical Team"),("General_Maintenance","General Maintenance")]
LIFECYCLE = ["New","Under Review","Awaiting Customer Information","Assigned","In Progress","Resolved","Closed"]

def w(rel, body):
    p = SRC / rel; p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text('<?xml version="1.0" encoding="UTF-8"?>\n' + textwrap.dedent(body).strip() + "\n")

def esc(s): return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")

def picklist_values(vals, default=None):
    return "".join(f"<value><fullName>{a}</fullName><default>{'true' if a==default else 'false'}</default><label>{esc(l)}</label></value>" for a,l in vals)

def field(obj, name, inner, label, help_=None, desc=None, track=False, feed=False):
    h = f"<inlineHelpText>{esc(help_)}</inlineHelpText>" if help_ else ""
    d = f"<description>{esc(desc)}</description>" if desc else ""
    t = "<trackHistory>true</trackHistory>" if track else ""
    f = "<trackFeedHistory>true</trackFeedHistory>" if feed else ""
    w(f"objects/{obj}/fields/{name}.field-meta.xml", f"<CustomField {NS}><fullName>{name}</fullName>{d}{h}<label>{esc(label)}</label>{t}{f}{inner}</CustomField>")

# ---------------- Global value set (CMP-002)
w("globalValueSets/Issue_Category.globalValueSet-meta.xml",
  f"<GlobalValueSet {NS}>{''.join(f'<customValue><fullName>{a}</fullName><default>false</default><label>{esc(l)}</label></customValue>' for a,l in CATEGORIES)}<masterLabel>Issue Category</masterLabel><sorted>true</sorted></GlobalValueSet>")

# ---------------- CaseStatus (CMP-024) — keeps the org's original values, adds the lifecycle
status_vals = LIFECYCLE + ["Working","Escalated"]
w("standardValueSets/CaseStatus.standardValueSet-meta.xml",
  f"<StandardValueSet {NS}><sorted>false</sorted>" + "".join(
    f"<standardValue><fullName>{s}</fullName><default>{'true' if s=='New' else 'false'}</default><label>{s}</label><closed>{'true' if s=='Closed' else 'false'}</closed></standardValue>" for s in status_vals) + "</StandardValueSet>")

# ---------------- Case object settings (CMP-013) + business process + record type
w("objects/Case/Case.object-meta.xml", f"""
<CustomObject {NS}>
  <enableFeeds>true</enableFeeds>
  <enableHistory>true</enableHistory>
  <externalSharingModel>Private</externalSharingModel>
  <sharingModel>Private</sharingModel>
</CustomObject>""")
w("objects/Case/businessProcesses/Maintenance_Request_Process.businessProcess-meta.xml",
  f"<BusinessProcess {NS}><fullName>Maintenance_Request_Process</fullName><description>Lifecycle statuses for maintenance requests (REQ-009).</description><isActive>true</isActive>" +
  "".join(f"<values><fullName>{s}</fullName><default>{'true' if s=='New' else 'false'}</default></values>" for s in LIFECYCLE) + "</BusinessProcess>")
w("objects/Case/recordTypes/Maintenance_Request.recordType-meta.xml", f"""
<RecordType {NS}>
  <fullName>Maintenance_Request</fullName>
  <active>true</active>
  <businessProcess>Maintenance_Request_Process</businessProcess>
  <description>Customer maintenance request (Reel Estate).</description>
  <label>Maintenance Request</label>
  <picklistValues><picklist>Issue_Category__c</picklist>{''.join(f'<values><fullName>{a}</fullName><default>false</default></values>' for a,_ in CATEGORIES)}</picklistValues>
  <picklistValues><picklist>Maintenance_Team__c</picklist>{''.join(f'<values><fullName>{a}</fullName><default>false</default></values>' for a,_ in TEAMS)}</picklistValues>
</RecordType>""")
# standard field history (Status, Owner, Priority)
for fld in ["Status","OwnerId","Priority"]:
    w(f"objects/Case/fields/{fld}.field-meta.xml", f"<CustomField {NS}><fullName>{fld}</fullName><trackFeedHistory>{'true' if fld!='Priority' else 'false'}</trackFeedHistory><trackHistory>true</trackHistory>{'<type>Picklist</type>' if fld!='OwnerId' else '<type>Lookup</type>'}</CustomField>")

# ---------------- Case custom fields
field("Case","Issue_Category__c","<required>false</required><type>Picklist</type><valueSet><restricted>true</restricted><valueSetName>Issue_Category</valueSetName></valueSet>","Issue Category",track=True,feed=True)
field("Case","Maintenance_Team__c",f"<required>false</required><type>Picklist</type><valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>{picklist_values(TEAMS)}</valueSetDefinition></valueSet>","Maintenance Team",track=True,feed=True)
field("Case","Escalation_Due__c","<required>false</required><type>DateTime</type>","Escalation Due","Date and time after which an unresolved request is escalated.")
field("Case","Is_Escalated__c","<defaultValue>false</defaultValue><type>Checkbox</type>","Escalated",track=True)
field("Case","Property__c","<deleteConstraint>Restrict</deleteConstraint><referenceTo>Property__c</referenceTo><relationshipLabel>Maintenance Requests</relationshipLabel><relationshipName>Maintenance_Requests</relationshipName><required>false</required><type>Lookup</type>","Property")
field("Case","Preferred_Appointment__c","<required>false</required><type>DateTime</type>","Preferred Appointment Time")
field("Case","Appointment_DateTime__c","<required>false</required><type>DateTime</type>","Appointment Date/Time","Date and time of the scheduled maintenance appointment.",track=True)
field("Case","Is_Overdue__c","<formula>AND(NOT(ISBLANK(Escalation_Due__c)), NOW() &gt; Escalation_Due__c, NOT(ISPICKVAL(Status, 'Resolved')), NOT(ISPICKVAL(Status, 'Closed')))</formula><formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs><type>Checkbox</type>","Overdue","Unresolved more than 5 days after submission.")
field("Case","Satisfaction_Rating__c","<precision>1</precision><scale>0</scale><required>false</required><type>Number</type><unique>false</unique>","Satisfaction Rating",track=True)
field("Case","Satisfaction_Response_Date__c","<required>false</required><type>DateTime</type>","Satisfaction Response Date","When the customer submitted their satisfaction rating.",track=True)
field("Case","Resolution_Outcome__c","<formula>IF(ISBLANK(Satisfaction_Rating__c), '', IF(Satisfaction_Rating__c &gt;= 3, 'Satisfactory - Resolved', 'Unresolved'))</formula><formulaTreatBlanksAs>BlankAsBlank</formulaTreatBlanksAs><type>Text</type><unique>false</unique>","Resolution Outcome")
w("objects/Case/validationRules/Satisfaction_Rating_Range.validationRule-meta.xml", f"""
<ValidationRule {NS}>
  <fullName>Satisfaction_Rating_Range</fullName>
  <active>true</active>
  <errorConditionFormula>AND(NOT(ISBLANK(Satisfaction_Rating__c)), OR(Satisfaction_Rating__c &lt; 1, Satisfaction_Rating__c &gt; 5))</errorConditionFormula>
  <errorDisplayField>Satisfaction_Rating__c</errorDisplayField>
  <errorMessage>Satisfaction rating must be a whole number from 1 to 5.</errorMessage>
</ValidationRule>""")

# ---------------- Property__c, Property_Customer__c (CMP-033..041)
def custom_object(api, label, plural, name_field, sharing, ext="Private", extra=""):
    w(f"objects/{api}/{api}.object-meta.xml", f"""
<CustomObject {NS}>
  <deploymentStatus>Deployed</deploymentStatus>
  <enableActivities>false</enableActivities>
  <enableBulkApi>true</enableBulkApi>
  <enableFeeds>false</enableFeeds>
  <enableHistory>false</enableHistory>
  <enableReports>true</enableReports>
  <enableSearch>true</enableSearch>
  <enableSharing>true</enableSharing>
  <enableStreamingApi>true</enableStreamingApi>
  <externalSharingModel>{ext}</externalSharingModel>
  <label>{label}</label>
  {name_field}
  <pluralLabel>{plural}</pluralLabel>
  <sharingModel>{sharing}</sharingModel>
  <visibility>Public</visibility>{extra}
</CustomObject>""")
custom_object("Property__c","Property","Properties","<nameField><label>Property Name</label><type>Text</type></nameField>","Read","Private")
field("Property__c","Street__c","<length>255</length><required>true</required><type>Text</type><unique>false</unique>","Street Address")
field("Property__c","City__c","<length>80</length><required>false</required><type>Text</type><unique>false</unique>","City")
field("Property__c","Postal_Code__c","<length>20</length><required>true</required><type>Text</type><unique>false</unique>","Postal Code")
custom_object("Property_Customer__c","Property Customer","Property Customers","<nameField><displayFormat>PC-{000000}</displayFormat><label>Property Customer Number</label><type>AutoNumber</type></nameField>","ControlledByParent","ControlledByParent")
field("Property_Customer__c","Property__c","<referenceTo>Property__c</referenceTo><relationshipLabel>Property Customers</relationshipLabel><relationshipName>Property_Customers</relationshipName><relationshipOrder>0</relationshipOrder><reparentableMasterDetail>false</reparentableMasterDetail><type>MasterDetail</type><writeRequiresMasterRead>false</writeRequiresMasterRead>","Property")
field("Property_Customer__c","Contact__c","<deleteConstraint>Restrict</deleteConstraint><referenceTo>Contact</referenceTo><relationshipLabel>Property Customers</relationshipLabel><relationshipName>Property_Customers</relationshipName><required>false</required><type>Lookup</type>","Contact")
field("Property_Customer__c","Property_Name__c","<formula>Property__r.Name</formula><formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs><type>Text</type><unique>false</unique>","Property Name")
field("Property_Customer__c","Relationship__c",f"<required>false</required><type>Picklist</type><valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>{picklist_values([('Owner','Owner'),('Tenant','Tenant')])}</valueSetDefinition></valueSet>","Relationship")

# ---------------- Request_Assignment__c (CMP-077..084)
custom_object("Request_Assignment__c","Request Assignment","Request Assignments","<nameField><displayFormat>RA-{000000}</displayFormat><label>Request Assignment Number</label><type>AutoNumber</type></nameField>","ControlledByParent","ControlledByParent")
field("Request_Assignment__c","Case__c","<referenceTo>Case</referenceTo><relationshipLabel>Request Assignments</relationshipLabel><relationshipName>Request_Assignments</relationshipName><relationshipOrder>0</relationshipOrder><reparentableMasterDetail>false</reparentableMasterDetail><type>MasterDetail</type><writeRequiresMasterRead>false</writeRequiresMasterRead>","Case")
field("Request_Assignment__c","Assignment_Type__c",f"<required>true</required><type>Picklist</type><valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>{picklist_values([('Representative','Representative'),('Team','Team')])}</valueSetDefinition></valueSet>","Assignment Type")
field("Request_Assignment__c","Assignee_User__c","<deleteConstraint>SetNull</deleteConstraint><referenceTo>User</referenceTo><relationshipName>Request_Assignments</relationshipName><required>false</required><type>Lookup</type>","Assignee")
field("Request_Assignment__c","Team__c",f"<required>false</required><type>Picklist</type><valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>{picklist_values(TEAMS)}</valueSetDefinition></valueSet>","Team")
field("Request_Assignment__c","Start__c","<required>true</required><type>DateTime</type>","Assignment Start")
field("Request_Assignment__c","End__c","<required>false</required><type>DateTime</type>","Assignment End")
field("Request_Assignment__c","Duration_Hours__c","<formula>IF(ISBLANK(End__c), NULL, (End__c - Start__c) * 24)</formula><formulaTreatBlanksAs>BlankAsBlank</formulaTreatBlanksAs><precision>10</precision><scale>2</scale><type>Number</type><unique>false</unique>","Resolution Time (Hours)")

# ---------------- Custom metadata types (CMP-004, 020, 043-046)
def mdt(api, label, plural, fields, records):
    w(f"objects/{api}/{api}.object-meta.xml", f"<CustomObject {NS}><label>{label}</label><pluralLabel>{plural}</pluralLabel><visibility>Public</visibility></CustomObject>")
    for fn, flabel, inner in fields:
        w(f"objects/{api}/fields/{fn}.field-meta.xml", f"<CustomField {NS}><fullName>{fn}</fullName><externalId>false</externalId><fieldManageability>SubscriberControlled</fieldManageability><label>{esc(flabel)}</label>{inner}</CustomField>")
    base = api.replace("__mdt","")
    for dev, rlabel, vals in records:
        body = "".join(
            (f"<values><field>{k}</field><value xsi:type=\"xsd:{t}\">{esc(str(v))}</value></values>" if v is not None else f"<values><field>{k}</field><value xsi:nil=\"true\"/></values>")
            for k,(t,v) in vals.items())
        w(f"customMetadata/{base}.{dev}.md-meta.xml", f'<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><label>{esc(rlabel)}</label><protected>false</protected>{body}</CustomMetadata>')

mdt("Category_Skill__mdt","Category Skill","Category Skills",[
    ("Issue_Category__c","Issue Category","<length>255</length><required>true</required><type>Text</type><unique>false</unique>"),
    ("Skill_Developer_Name__c","Skill Developer Name","<length>80</length><required>true</required><type>Text</type><unique>false</unique>"),
    ("Skill_Level__c","Skill Level","<defaultValue>1</defaultValue><precision>2</precision><required>false</required><scale>0</scale><type>Number</type><unique>false</unique>"),
    ("Active__c","Active","<defaultValue>true</defaultValue><type>Checkbox</type>")],
    [(a, l, {"Issue_Category__c":("string",a),"Skill_Developer_Name__c":("string",a),"Skill_Level__c":("double",1),"Active__c":("boolean","true")}) for a,l in CATEGORIES])
mdt("Request_Setting__mdt","Request Setting","Request Settings",[
    ("Escalation_Days__c","Escalation Days","<inlineHelpText>Calendar days from submission before an unresolved request is escalated</inlineHelpText><precision>3</precision><required>true</required><scale>0</scale><type>Number</type><unique>false</unique>"),
    ("Auto_Close_Days__c","Auto Close Days","<precision>3</precision><required>false</required><scale>0</scale><type>Number</type><unique>false</unique>"),
    ("Org_Wide_Email_Address__c","Org Wide Email Address","<required>false</required><type>Email</type><unique>false</unique>"),
    ("Portal_Url__c","Portal URL","<inlineHelpText>Base URL of the customer portal, e.g. https://acme.my.site.com/maintenance</inlineHelpText><length>255</length><required>false</required><type>Text</type><unique>false</unique>"),
    ("Allowed_File_Extensions__c","Allowed File Extensions","<length>255</length><required>false</required><type>Text</type><unique>false</unique>"),
    ("Max_File_Size_KB__c","Max File Size (KB)","<precision>6</precision><required>false</required><scale>0</scale><type>Number</type><unique>false</unique>"),
    ("Max_File_Count__c","Max File Count","<precision>2</precision><required>false</required><scale>0</scale><type>Number</type><unique>false</unique>")],
    [("Default","Default",{"Escalation_Days__c":("double",5),"Auto_Close_Days__c":("double",42),"Org_Wide_Email_Address__c":("string",None),"Portal_Url__c":("string","https://orgfarm-3b22af62d2-dev-ed.develop.my.site.com/maintenance"),
      "Allowed_File_Extensions__c":("string","jpg,jpeg,png,pdf,heic"),"Max_File_Size_KB__c":("double",1024),"Max_File_Count__c":("double",3)})])
mdt("Notification_Rule__mdt","Notification Rule","Notification Rules",[
    ("Event__c","Event",f"<required>false</required><type>Picklist</type><valueSet><restricted>true</restricted><valueSetDefinition><sorted>false</sorted>{picklist_values([('Submitted','Submitted'),('Status_Changed','Status Changed'),('Appointment_Set','Appointment Set')])}</valueSetDefinition></valueSet>"),
    ("Status__c","Status","<length>40</length><required>false</required><type>Text</type><unique>false</unique>"),
    ("Excluded_Statuses__c","Excluded Statuses","<inlineHelpText>Comma-separated statuses this rule does not fire for (used by the generic status rule).</inlineHelpText><length>255</length><required>false</required><type>Text</type><unique>false</unique>"),
    ("Email_Template__c","Email Template","<length>80</length><required>false</required><type>Text</type><unique>false</unique>"),
    ("Notification_Type__c","Notification Type","<length>80</length><required>false</required><type>Text</type><unique>false</unique>"),
    ("Notification_Title__c","Notification Title","<length>120</length><required>false</required><type>Text</type><unique>false</unique>"),
    ("Sender_Address__c","Sender Address","<required>false</required><type>Email</type><unique>false</unique>"),
    ("Active__c","Active","<defaultValue>true</defaultValue><type>Checkbox</type>")],
    [(dev,label,{"Event__c":("string",ev),"Status__c":("string",st),"Excluded_Statuses__c":("string",ex),"Email_Template__c":("string",tpl),
       "Notification_Type__c":("string","Maintenance_Request_Message"),"Notification_Title__c":("string",title),"Sender_Address__c":("string",None),"Active__c":("boolean","true")})
     for dev,label,ev,st,ex,tpl,title in [
       ("Request_Submitted","Request Submitted","Submitted",None,None,"Maintenance_Request_Acknowledgement","Request received"),
       ("Status_Changed","Status Changed","Status_Changed",None,"Resolved,Awaiting Customer Information","Maintenance_Request_Status_Changed","Request status updated"),
       ("Request_Resolved","Request Resolved","Status_Changed","Resolved",None,"Maintenance_Request_Resolved","Request resolved"),
       ("Information_Required","Information Required","Status_Changed","Awaiting Customer Information",None,"Maintenance_Information_Required","More information needed"),
       ("Appointment_Scheduled","Appointment Scheduled","Appointment_Set",None,None,"Maintenance_Appointment_Scheduled","Appointment scheduled")]])

# ---------------- Queue, groups (CMP-023, 066, 126)
w("queues/Maintenance_Escalation.queue-meta.xml", f"<Queue {NS}><fullName>Maintenance_Escalation</fullName><doesSendEmailToMembers>false</doesSendEmailToMembers><name>Maintenance Escalation Team</name><queueSobject><sobjectType>Case</sobjectType></queueSobject></Queue>")
w("queues/Maintenance_Requests.queue-meta.xml", f"<Queue {NS}><fullName>Maintenance_Requests</fullName><doesSendEmailToMembers>false</doesSendEmailToMembers><name>Maintenance Requests (Unrouted)</name><queueSobject><sobjectType>Case</sobjectType></queueSobject></Queue>")
w("groups/Maintenance_Supervisors_Managers.group-meta.xml", f"<Group {NS}><fullName>Maintenance_Supervisors_Managers</fullName><doesIncludeBosses>false</doesIncludeBosses><name>Maintenance Supervisors &amp; Managers</name></Group>")
for a,l in TEAMS:
    w(f"groups/Maintenance_Team_{a}.group-meta.xml", f"<Group {NS}><fullName>Maintenance_Team_{a}</fullName><doesIncludeBosses>false</doesIncludeBosses><name>{esc(l)}</name></Group>")

# ---------------- Sharing rules (CMP-067, 127)
crit = lambda team=None: ("<criteriaItems><field>RecordTypeId</field><operation>equals</operation><value>Maintenance Request</value></criteriaItems>" +
                         (f"<criteriaItems><field>Maintenance_Team__c</field><operation>equals</operation><value>{esc(dict(TEAMS)[team])}</value></criteriaItems>" if team else ""))
rules = f"""<sharingCriteriaRules><fullName>Maintenance_Supervisors_Managers_All</fullName><accessLevel>Edit</accessLevel><label>Maintenance Supervisors Managers All</label><sharedTo><group>Maintenance_Supervisors_Managers</group></sharedTo>{crit()}<includeRecordsOwnedByAll>true</includeRecordsOwnedByAll></sharingCriteriaRules>"""
for a,l in TEAMS:
    rules += f"""<sharingCriteriaRules><fullName>Maintenance_Team_{a}_Access</fullName><accessLevel>Edit</accessLevel><label>{esc(l)} Access</label><sharedTo><group>Maintenance_Team_{a}</group></sharedTo>{crit(a)}<includeRecordsOwnedByAll>true</includeRecordsOwnedByAll></sharingCriteriaRules>"""
w("sharingRules/Case.sharingRules-meta.xml", f"<SharingRules {NS}>{rules}</SharingRules>")

# ---------------- Custom notification type (CMP-027)
w("notificationtypes/Maintenance_Request_Message.notiftype-meta.xml", f"<CustomNotificationType {NS}><customNotifTypeName>Maintenance Request Message</customNotifTypeName><desktop>true</desktop><masterLabel>Maintenance Request Message</masterLabel><mobile>true</mobile></CustomNotificationType>")

# ---------------- Email templates (classic HTML, folder) CMP-026,058,093-095,101,102
w("email/Maintenance_Request_Templates.emailFolder-meta.xml", f"<EmailFolder {NS}><accessType>Public</accessType><name>Maintenance Request Templates</name><publicFolderAccess>ReadWrite</publicFolderAccess></EmailFolder>")
def tpl(dev, name, subject, html):
    body = f"""<html><body style="font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.5;color:#1b1b1b">
<p>Hello {{!Contact.FirstName}},</p>
{html}
<p>Request number: <strong>{{!Case.CaseNumber}}</strong><br/>Category: {{!Case.Issue_Category__c}}</p>
<p><a href="{{!Case.Portal_Link__c}}">View your request in the customer portal</a></p>
<p>Reel Estate Customer Service</p></body></html>"""
    text = f"Hello {{!Contact.FirstName}},\n\n{subject}\n\nRequest number: {{!Case.CaseNumber}}\nView your request: {{!Case.Portal_Link__c}}\n\nReel Estate Customer Service"
    d = SRC / "email/Maintenance_Request_Templates"; d.mkdir(parents=True, exist_ok=True)
    (d / f"{dev}.email").write_text(body)
    w(f"email/Maintenance_Request_Templates/{dev}.email-meta.xml", f"<EmailTemplate {NS}><available>true</available><encodingKey>UTF-8</encodingKey><name>{esc(name)}</name><style>none</style><subject>{esc(subject)}</subject><textOnly>{esc(text)}</textOnly><type>custom</type><uiType>Aloha</uiType></EmailTemplate>")
tpl("Maintenance_Customer_Message","Maintenance Customer Message","Update on your maintenance request {!Case.CaseNumber}",
    "<p>Your representative has sent you a message about your maintenance request:</p><blockquote>[[MESSAGE_BODY]]</blockquote><p>Please reply through the customer portal.</p>")
tpl("Maintenance_Information_Reminder","Maintenance Information Reminder","Reminder: information needed for request {!Case.CaseNumber}",
    "<p>We are still waiting for the information we asked for so we can progress your request <em>{!Case.Subject}</em>.</p><p>[[MESSAGE_BODY]]</p>")
tpl("Maintenance_Request_Acknowledgement","Maintenance Request Acknowledgement","We received your maintenance request {!Case.CaseNumber}",
    "<p>Thank you. We have received your maintenance request and a customer service representative will be in touch.</p>")
tpl("Maintenance_Request_Status_Changed","Maintenance Request Status Changed","Update on your maintenance request {!Case.CaseNumber}",
    "<p>The status of your maintenance request is now <strong>{!Case.Status}</strong>.</p>")
tpl("Maintenance_Request_Resolved","Maintenance Request Resolved","Your maintenance request {!Case.CaseNumber} has been resolved",
    "<p>The work on your maintenance request is complete. Please confirm whether your issue is resolved by rating it in the customer portal.</p>")
tpl("Maintenance_Information_Required","Maintenance Information Required","Action needed: more information for request {!Case.CaseNumber}",
    "<p>We need some more information to progress your request. Please reply through the customer portal.</p>")
tpl("Maintenance_Appointment_Scheduled","Maintenance Appointment Scheduled","Appointment scheduled for request {!Case.CaseNumber}",
    "<p>An appointment has been scheduled for <strong>{!Case.Appointment_DateTime__c}</strong>. Please make sure someone is available.</p>")
field("Case","Portal_Link__c","<formula>$CustomMetadata.Request_Setting__mdt.Default.Portal_Url__c &amp; '/s/case/' &amp; CASESAFEID(Id)</formula><formulaTreatBlanksAs>BlankAsZero</formulaTreatBlanksAs><type>Text</type><unique>false</unique>","Portal Link")
#w("labels/CustomLabels.labels-meta.xml", f"<CustomLabels {NS}><labels><fullName>Maintenance_Portal_Url</fullName><language>en_US</language><protected>false</protected><shortDescription>Maintenance Portal Url</shortDescription><value>https://example.my.site.com/maintenance</value></labels></CustomLabels>")

# ---------------- List views (CMP-010, 056, 069, 070)
def listview(name, label, scope, cols, filters, shared=None):
    f = "".join(f"<filters><field>{a}</field><operation>{b}</operation><value>{c}</value></filters>" for a,b,c in filters)
    s = f"<sharedTo><group>{shared}</group></sharedTo>" if shared else ""
    w(f"objects/Case/listViews/{name}.listView-meta.xml", f"<ListView {NS}><fullName>{name}</fullName>{''.join(f'<columns>{c}</columns>' for c in cols)}<filterScope>{scope}</filterScope>{f}<label>{label}</label>{s}</ListView>")
RT = ("CASES.RECORDTYPE","equals","Case.Maintenance_Request")
listview("My_Maintenance_Requests","My Maintenance Requests","Mine",["CASES.CASE_NUMBER","CASES.SUBJECT","Issue_Category__c","CASES.STATUS","CASES.PRIORITY","CASES.CREATED_DATE_DATE_ONLY","NAME"],[RT])
listview("All_Maintenance_Requests","All Maintenance Requests","Everything",["CASES.CASE_NUMBER","CASES.SUBJECT","CASES.STATUS","Issue_Category__c","Maintenance_Team__c","CORE.USERS.ALIAS","CASES.CREATED_DATE_DATE_ONLY","Is_Overdue__c"],[RT],"Maintenance_Supervisors_Managers")
listview("Overdue_Maintenance_Requests","Overdue Maintenance Requests","Everything",["CASES.CASE_NUMBER","CASES.SUBJECT","CASES.STATUS","Issue_Category__c","CORE.USERS.ALIAS","Maintenance_Team__c","CASES.CREATED_DATE_DATE_ONLY","Escalation_Due__c"],[RT,("Is_Overdue__c","equals","1")],"Maintenance_Supervisors_Managers")
listview("Portal_Maintenance_Requests","My Requests","Everything",["CASES.CASE_NUMBER","CASES.SUBJECT","Issue_Category__c","CASES.STATUS","CASES.CREATED_DATE_DATE_ONLY","CASES.LAST_UPDATE_DATE_ONLY"],[RT])
print("generated")
