#!/usr/bin/env python3
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from gen_metadata import w, NS, esc, CATEGORIES, TEAMS

# ---------------- Permission sets
CASE_FIELDS_ALL = ["Issue_Category__c","Maintenance_Team__c","Escalation_Due__c","Is_Escalated__c","Property__c","Preferred_Appointment__c",
                   "Appointment_DateTime__c","Is_Overdue__c","Satisfaction_Rating__c","Satisfaction_Response_Date__c","Resolution_Outcome__c","Portal_Link__c"]
FORMULA = {"Is_Overdue__c","Resolution_Outcome__c","Portal_Link__c","Duration_Hours__c"}
def ps(name, label, desc, objects=(), fields=(), classes=(), flows=(), rts=(), tabs=(), userperms=(), presence=(), apps=()):
    o = "".join(f"<objectPermissions><allowCreate>{'true' if 'C' in p else 'false'}</allowCreate><allowDelete>{'true' if 'D' in p else 'false'}</allowDelete><allowEdit>{'true' if 'E' in p else 'false'}</allowEdit><allowRead>true</allowRead><modifyAllRecords>false</modifyAllRecords><object>{ob}</object><viewAllRecords>false</viewAllRecords></objectPermissions>" for ob,p in objects)
    f = "".join(f"<fieldPermissions><editable>{'true' if (e and fl.split('.')[1] not in FORMULA) else 'false'}</editable><field>{fl}</field><readable>true</readable></fieldPermissions>" for fl,e in fields)
    c = "".join(f"<classAccesses><apexClass>{x}</apexClass><enabled>true</enabled></classAccesses>" for x in classes)
    fa = "".join(f"<flowAccesses><enabled>true</enabled><flow>{x}</flow></flowAccesses>" for x in flows)
    r = "".join(f"<recordTypeVisibilities><recordType>{x}</recordType><visible>true</visible></recordTypeVisibilities>" for x in rts)
    t = "".join(f"<tabSettings><tab>{x}</tab><visibility>Visible</visibility></tabSettings>" for x in tabs)
    u = "".join(f"<userPermissions><enabled>true</enabled><name>{x}</name></userPermissions>" for x in userperms)
    sp = "".join(f"<servicePresenceStatusAccesses><servicePresenceStatus>{x}</servicePresenceStatus></servicePresenceStatusAccesses>" for x in presence)
    # Metadata API element order for PermissionSet
    a = "".join(f"<applicationVisibilities><application>{x}</application><visible>true</visible></applicationVisibilities>" for x in apps)
    w(f"permissionsets/{name}.permissionset-meta.xml",
      f"<PermissionSet {NS}>{a}{c}<description>{esc(desc)}</description>{f}{fa}<hasActivationRequired>false</hasActivationRequired><label>{esc(label)}</label>{o}{r}{t}{u}</PermissionSet>")

case = lambda *names, edit=False: [(f"Case.{n}", edit) for n in names]
ps("Maintenance_CSR","Maintenance CSR","CMP-016. Customer service representatives: work their own maintenance requests.",
   objects=[("Case","CE"),("Contact","")],
   fields=[("Case.Subject",True),("Case.Description",True),("Case.Origin",True),("Case.Priority",True),("Case.ContactId",True),("Case.AccountId",True),("Case.ParentId",False),("Case.SuppliedName",False),("Case.SuppliedEmail",False),("Case.SuppliedPhone",False)]+case("Issue_Category__c","Maintenance_Team__c","Appointment_DateTime__c",edit=True)+case("Property__c","Preferred_Appointment__c","Escalation_Due__c","Is_Escalated__c","Is_Overdue__c","Satisfaction_Rating__c","Portal_Link__c"),
   classes=["CaseSkillRoutingService","CaseTriggerHandler","MaintenanceCustomerMessageAction","MaintenanceNotificationService"],
   flows=["Maintenance_Send_Reminder","Maintenance_Send_Reminder_Action","Maintenance_Link_Customer_Property"],
   rts=["Case.Maintenance_Request"], tabs=["standard-Case"], apps=["Reel_Estate_Maintenance"], userperms=["EditEvent","EditTask","RunFlow"], presence=["Available_Maintenance_Requests"])
ps("Maintenance_Portal_Customer","Maintenance Portal Customer","CMP-017. Experience Cloud customers: read their own requests and message the team.",
   objects=[("Case","")], fields=case("Issue_Category__c","Property__c","Preferred_Appointment__c","Appointment_DateTime__c","Portal_Link__c"), rts=["Case.Maintenance_Request"])
ps("Maintenance_Portal_Rating","Maintenance Portal Rating","CMP-119. Lets portal customers rate a resolved request.",
   objects=[("Case","E")], fields=case("Satisfaction_Rating__c",edit=True)+case("Satisfaction_Response_Date__c","Resolution_Outcome__c"), flows=["Maintenance_Rate_Request"])
ps("Maintenance_Request_Admin","Maintenance Request Admin","CMP-032. Configures categories, statuses, escalation days and notification rules.",
   objects=[("Case","")], fields=case("Escalation_Due__c","Is_Escalated__c"), userperms=["CustomizeApplication","ManageCustomPermissions","ManageTranslation","ViewRoles","ViewSetup"])
ps("Maintenance_Intake_Guest","Maintenance Intake Guest","CMP-053. Site guest user: may call the intake controller only.", classes=["MaintenanceRequestIntakeController"])
ps("Maintenance_Property_User","Maintenance Property User","CMP-055. Internal users: read and maintain properties and their customers.",
   objects=[("Property__c","CE"),("Property_Customer__c","CE")],
   fields=[("Property__c.City__c",True),("Property_Customer__c.Contact__c",True),("Property_Customer__c.Relationship__c",True)]+case("Property__c",edit=True)+case("Preferred_Appointment__c"),
   tabs=["Property__c"], flows=["Maintenance_Link_Customer_Property"])
ps("Maintenance_Supervisor_Manager","Maintenance Supervisor/Manager","CMP-068. Read every maintenance request and run management reports.",
   objects=[("Case",""),("Property__c",""),("Contact",""),("Account","")],
   fields=case("Issue_Category__c","Property__c","Preferred_Appointment__c","Maintenance_Team__c","Escalation_Due__c","Is_Escalated__c","Is_Overdue__c","Appointment_DateTime__c","Satisfaction_Rating__c","Resolution_Outcome__c"),
   rts=["Case.Maintenance_Request"], tabs=["standard-Case","standard-Dashboard","standard-report"], apps=["Reel_Estate_Maintenance"], userperms=["RunReports"])
ps("Maintenance_Manager_Insights","Maintenance Manager Insights","CMP-092. Read assignment periods and satisfaction for reporting.",
   objects=[("Case",""),("Request_Assignment__c","")],
   fields=[(f"Request_Assignment__c.{x}",False) for x in ["Assignee_User__c","Team__c","End__c","Duration_Hours__c"]]+case("Satisfaction_Rating__c"), userperms=["RunReports"])
ps("Maintenance_Resolution_Confirmation","Maintenance Resolution Confirmation","CMP-120. Request information and confirm resolution flows.",
   fields=case("Satisfaction_Response_Date__c","Resolution_Outcome__c"),
   flows=["Maintenance_Request_Information","Maintenance_Request_Information_Action","Maintenance_Confirm_Resolution","Maintenance_Confirm_Resolution_Action"], userperms=["RunFlow"])
ps("Maintenance_Team_Member","Maintenance Team Member","CMP-128. Maintenance team users: edit requests assigned to their team.",
   objects=[("Case","E"),("Property__c","")],
   fields=case("Appointment_DateTime__c",edit=True)+case("Issue_Category__c","Property__c","Preferred_Appointment__c","Maintenance_Team__c","Escalation_Due__c","Is_Overdue__c","Satisfaction_Rating__c","Is_Escalated__c","Satisfaction_Response_Date__c"),
   rts=["Case.Maintenance_Request"], tabs=["standard-Case"])

# Demo/admin access to everything this solution adds (assigned to the org admin and demo users who configure it)
ALL_FIELDS = [(f"Case.{f}", True) for f in CASE_FIELDS_ALL] + [("Property__c.City__c",True),("Property_Customer__c.Contact__c",True),("Property_Customer__c.Relationship__c",True),("Property_Customer__c.Property_Name__c",False)] + \
    [(f"Request_Assignment__c.{x}",True) for x in ["Assignee_User__c","Team__c","End__c","Duration_Hours__c"]]
ps("Maintenance_Full_Access","Maintenance Full Access","Admin and demo access to every object and field in the maintenance solution.",
   objects=[("Case","CE"),("Contact","CE"),("Account","CE"),("Property__c","CED"),("Property_Customer__c","CED"),("Request_Assignment__c","CED")], fields=ALL_FIELDS,
   flows=["Maintenance_Send_Reminder","Maintenance_Send_Reminder_Action","Maintenance_Link_Customer_Property","Maintenance_Request_Information","Maintenance_Request_Information_Action","Maintenance_Confirm_Resolution","Maintenance_Confirm_Resolution_Action","Maintenance_Rate_Request"],
   rts=["Case.Maintenance_Request"], tabs=["Property__c"], apps=["Reel_Estate_Maintenance"])

# ---------------- Quick actions
w("quickActions/Case.Assign_Maintenance_Team.quickAction-meta.xml", f"""<QuickAction {NS}><label>Assign Maintenance Team</label><optionsCreateFeedItem>false</optionsCreateFeedItem>
<quickActionLayout><layoutSectionStyle>TwoColumnsLeftToRight</layoutSectionStyle><quickActionLayoutColumns><quickActionLayoutItems><emptySpace>false</emptySpace><field>Maintenance_Team__c</field><uiBehavior>Required</uiBehavior></quickActionLayoutItems></quickActionLayoutColumns><quickActionLayoutColumns/></quickActionLayout>
<successMessage>Maintenance team assigned</successMessage><type>Update</type></QuickAction>""")
for api, label, flowname in [("Send_Reminder","Send Reminder","Maintenance_Send_Reminder"),("Link_Customer_Property","Link Customer &amp; Property","Maintenance_Link_Customer_Property"),
                             ("Request_Information","Request Information","Maintenance_Request_Information"),("Confirm_Resolution","Confirm Resolution with Customer","Maintenance_Confirm_Resolution")]:
    w(f"quickActions/Case.{api}.quickAction-meta.xml", f"<QuickAction {NS}><flowDefinition>{flowname}</flowDefinition><label>{label}</label><optionsCreateFeedItem>false</optionsCreateFeedItem><type>Flow</type></QuickAction>")

# ---------------- Layouts
def li(field, beh="Edit"): return f"<layoutItems><behavior>{beh}</behavior><field>{field}</field></layoutItems>"
def section(label, left, right, style="TwoColumnsTopToBottom", custom=True):
    return f"<layoutSections><customLabel>{'true' if custom else 'false'}</customLabel><detailHeading>true</detailHeading><editHeading>true</editHeading><label>{esc(label)}</label><layoutColumns>{''.join(left)}</layoutColumns>{"" if style=="OneColumn" else "<layoutColumns>"+"".join(right)+"</layoutColumns>"}<style>{style}</style></layoutSections>"
actions = ["FeedItem.TextPost","Case.Assign_Maintenance_Team","Case.Request_Information","Case.Send_Reminder","Case.Confirm_Resolution","Case.Link_Customer_Property","Edit","ChangeOwnerOne","FeedItem.ContentPost"]
pal = "".join(f"<platformActionListItems><actionName>{a}</actionName><actionType>{'StandardButton' if a in ('Edit','ChangeOwnerOne') else 'QuickAction'}</actionType><sortOrder>{i}</sortOrder></platformActionListItems>" for i,a in enumerate(actions))
w("layouts/Case-Maintenance Request Layout.layout-meta.xml", f"""<Layout {NS}>
{section("Request", [li("CaseNumber","Readonly"),li("Status","Required"),li("Priority"),li("Issue_Category__c"),li("Maintenance_Team__c"),li("Origin")],
         [li("OwnerId","Edit"),li("ContactId"),li("AccountId"),li("Property__c"),li("ParentId")])}
{section("Description", [li("Subject"),li("Description")], [], "OneColumn")}
{section("Scheduling and escalation", [li("Preferred_Appointment__c","Readonly"),li("Appointment_DateTime__c")],
         [li("Escalation_Due__c","Readonly"),li("Is_Overdue__c","Readonly"),li("Is_Escalated__c","Readonly")])}
{section("Customer satisfaction", [li("Satisfaction_Rating__c","Readonly"),li("Resolution_Outcome__c","Readonly")],[li("Satisfaction_Response_Date__c","Readonly"),li("ClosedDate","Readonly")])}
{section("Web submission", [li("SuppliedName","Readonly"),li("SuppliedEmail","Readonly")],[li("SuppliedPhone","Readonly"),li("Portal_Link__c","Readonly")])}
<platformActionList><actionListContext>Record</actionListContext>{pal}</platformActionList>
<relatedLists><fields>NAME</fields><fields>Assignment_Type__c</fields><fields>Assignee_User__c</fields><fields>Team__c</fields><fields>Start__c</fields><fields>End__c</fields><fields>Duration_Hours__c</fields><relatedList>Request_Assignment__c.Case__c</relatedList></relatedLists>
<relatedLists><relatedList>RelatedEntityHistoryList</relatedList></relatedLists>
<relatedLists><relatedList>RelatedFileList</relatedList></relatedLists>
<relatedLists><relatedList>RelatedActivityList</relatedList></relatedLists>
<relatedLists><relatedList>RelatedHistoryList</relatedList></relatedLists>
<showEmailCheckbox>false</showEmailCheckbox><showHighlightsPanel>false</showHighlightsPanel><showInteractionLogPanel>false</showInteractionLogPanel><showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox><showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>""")
w("layouts/Property__c-Property Layout.layout-meta.xml", f"""<Layout {NS}>
{section("Property", [li("Name","Required"),li("Street__c","Required")], [li("City__c"),li("Postal_Code__c","Required")])}
<relatedLists><fields>NAME</fields><fields>Contact__c</fields><fields>Relationship__c</fields><relatedList>Property_Customer__c.Property__c</relatedList></relatedLists>
<relatedLists><fields>CASES.CASE_NUMBER</fields><fields>CASES.STATUS</fields><fields>Issue_Category__c</fields><fields>CASES.CREATED_DATE_DATE_ONLY</fields><relatedList>Case.Property__c</relatedList><sortField>CASES.CREATED_DATE_DATE_ONLY</sortField><sortOrder>Desc</sortOrder></relatedLists>
<showEmailCheckbox>false</showEmailCheckbox><showHighlightsPanel>false</showHighlightsPanel><showInteractionLogPanel>false</showInteractionLogPanel><showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox><showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>""")
w("layouts/Property_Customer__c-Property Customer Layout.layout-meta.xml", f"""<Layout {NS}>
{section("Property Customer", [li("Name","Readonly"),li("Property__c","Required")], [li("Contact__c"),li("Relationship__c")])}
<showEmailCheckbox>false</showEmailCheckbox><showHighlightsPanel>false</showHighlightsPanel><showInteractionLogPanel>false</showInteractionLogPanel><showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox><showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>""")
w("layouts/Request_Assignment__c-Request Assignment Layout.layout-meta.xml", f"""<Layout {NS}>
{section("Assignment", [li("Name","Readonly"),li("Case__c","Required"),li("Assignment_Type__c","Required")], [li("Assignee_User__c"),li("Team__c"),li("Start__c","Required"),li("End__c"),li("Duration_Hours__c","Readonly")])}
<showEmailCheckbox>false</showEmailCheckbox><showHighlightsPanel>false</showHighlightsPanel><showInteractionLogPanel>false</showInteractionLogPanel><showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox><showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>""")
# Admin profile: layout assignment + default record type (demo user)
w("profiles/Admin.profile-meta.xml", f"""<Profile {NS}><custom>false</custom>
<layoutAssignments><layout>Case-Maintenance Request Layout</layout><recordType>Case.Maintenance_Request</recordType></layoutAssignments>
<layoutAssignments><layout>Property__c-Property Layout</layout></layoutAssignments>
<layoutAssignments><layout>Property_Customer__c-Property Customer Layout</layout></layoutAssignments>
<layoutAssignments><layout>Request_Assignment__c-Request Assignment Layout</layout></layoutAssignments>
<recordTypeVisibilities><default>true</default><recordType>Case.Maintenance_Request</recordType><visible>true</visible></recordTypeVisibilities>
</Profile>""")

# ---------------- Path + Lightning record page (CMP-014)
w("pathAssistants/Maintenance_Request_Path.pathAssistant-meta.xml", f"""<PathAssistant {NS}><active>true</active><entityName>Case</entityName><fieldName>Status</fieldName><masterLabel>Maintenance Request Path</masterLabel><recordTypeName>Maintenance_Request</recordTypeName>
<pathAssistantSteps><fieldNames>Maintenance_Team__c</fieldNames><info>&lt;p&gt;Assign a maintenance team once the request is understood.&lt;/p&gt;</info><picklistValueName>Assigned</picklistValueName></pathAssistantSteps>
<pathAssistantSteps><fieldNames>Appointment_DateTime__c</fieldNames><info>&lt;p&gt;Schedule the appointment; the customer is notified automatically.&lt;/p&gt;</info><picklistValueName>In Progress</picklistValueName></pathAssistantSteps>
</PathAssistant>""")
def comp(name, ident, props=()):
    p = "".join(f"<componentInstanceProperties><name>{k}</name><value>{v}</value></componentInstanceProperties>" for k,v in props)
    return f"<itemInstances><componentInstance>{p}<componentName>{name}</componentName><identifier>{ident}</identifier></componentInstance></itemInstances>"
def region(name, items, typ="Region"): return f"<flexiPageRegions>{''.join(items)}<name>{name}</name><type>{typ}</type></flexiPageRegions>"
w("flexipages/Maintenance_Request_Record_Page.flexipage-meta.xml", f"""<FlexiPage {NS}>
{region("feedTabContent",[comp("forceChatter:recordFeedContainer","feed")],"Facet")}
{region("detailTabContent",[comp("force:detailPanel","detail")],"Facet")}
{region("relatedTabContent",[comp("force:relatedListContainer","related")],"Facet")}
{region("maintabs",[comp("flexipage:tab","feedTab",[("active","true"),("body","feedTabContent"),("title","Standard.Tab.feed")]),
                     comp("flexipage:tab","detailTab",[("body","detailTabContent"),("title","Standard.Tab.detail")]),
                     comp("flexipage:tab","relatedTab",[("body","relatedTabContent"),("title","Standard.Tab.relatedLists")])],"Facet")}
{region("header",[comp("force:highlightsPanel","highlights",[("collapsed","false"),("numVisibleActions","6")]),comp("runtime_sales_pathassistant:pathAssistant","path",[("hideUpdateButton","false"),("variant","linear")])])}
{region("main",[comp("flexipage:tabset","tabs",[("tabs","maintabs")])])}
{region("sidebar",[comp("force:relatedListSingleContainer","files",[("parentFieldApiName","Case.Id"),("relatedListApiName","CombinedAttachments"),("relatedListComponentOverride","NONE"),("rowsToDisplay","5"),("showActionBar","true")]),
                    comp("force:relatedListSingleContainer","history",[("parentFieldApiName","Case.Id"),("relatedListApiName","Histories"),("relatedListComponentOverride","NONE"),("rowsToDisplay","10"),("showActionBar","false")])])}
<masterLabel>Maintenance Request Record Page</masterLabel><sobjectType>Case</sobjectType><template><name>flexipage:recordHomeTemplateDesktop</name></template><type>RecordPage</type>
</FlexiPage>""")

# ---------------- Omni-Channel (CMP-005)
w("settings/OmniChannel.settings-meta.xml", f"<OmniChannelSettings {NS}><enableOmniChannel>true</enableOmniChannel><enableOmniSkillsRouting>true</enableOmniSkillsRouting></OmniChannelSettings>")
w("settings/PathAssistant.settings-meta.xml", f"<PathAssistantSettings {NS}><pathAssistantEnabled>true</pathAssistantEnabled></PathAssistantSettings>")
w("serviceChannels/Maintenance_Request_Case.serviceChannel-meta.xml", f"<ServiceChannel {NS}><label>Maintenance Request Case</label><relatedEntityType>Case</relatedEntityType></ServiceChannel>")
w("servicePresenceStatuses/Available_Maintenance_Requests.servicePresenceStatus-meta.xml", f"<ServicePresenceStatus {NS}><channels><channel>Maintenance_Request_Case</channel></channels><label>Available - Maintenance Requests</label></ServicePresenceStatus>")
w("presenceUserConfigs/CSR_Presence.presenceUserConfig-meta.xml", f"<PresenceUserConfig {NS}><capacity>5</capacity><enableAutoAccept>false</enableAutoAccept><enableDecline>true</enableDecline><enableDeclineReason>false</enableDeclineReason><enableDisconnectSound>false</enableDisconnectSound><enableRequestSound>true</enableRequestSound><label>CSR Presence</label></PresenceUserConfig>")
for a,l in CATEGORIES:
    w(f"skills/{a}.skill-meta.xml", f"<Skill {NS}><label>{esc(l)}</label></Skill>")

# ---------------- Tabs + app
w("tabs/Property__c.tab-meta.xml", f"<CustomTab {NS}><customObject>true</customObject><motif>Custom24: Building</motif></CustomTab>")
w("objects/Case/Case.object-meta.xml", f"""<CustomObject {NS}>
  <actionOverrides><actionName>View</actionName><content>Maintenance_Request_Record_Page</content><formFactor>Large</formFactor><skipRecordTypeSelect>false</skipRecordTypeSelect><type>Flexipage</type></actionOverrides>
  <enableFeeds>true</enableFeeds>
  <enableHistory>true</enableHistory>
  <externalSharingModel>Private</externalSharingModel>
  <sharingModel>Private</sharingModel>
</CustomObject>""")
tabs = ["standard-Case","Property__c","standard-Contact","standard-Account","standard-report","standard-Dashboard"]
w("applications/Reel_Estate_Maintenance.app-meta.xml", f"""<CustomApplication {NS}>
<brand><headerColor>#0B5CAB</headerColor><shouldOverrideOrgTheme>false</shouldOverrideOrgTheme></brand>
<description>Service console for Reel Estate maintenance requests.</description>
<formFactors>Large</formFactors><isNavAutoTempTabsDisabled>false</isNavAutoTempTabsDisabled><isNavPersonalizationDisabled>false</isNavPersonalizationDisabled><isNavTabPersistenceDisabled>false</isNavTabPersistenceDisabled>
<label>Reel Estate Maintenance</label><navType>Console</navType>
{''.join(f'<profileActionOverrides><actionName>View</actionName><content>Maintenance_Request_Record_Page</content><formFactor>Large</formFactor><pageOrSobjectType>Case</pageOrSobjectType><recordType>Case.Maintenance_Request</recordType><type>Flexipage</type><profile>{pr}</profile></profileActionOverrides>' for pr in ['Admin','Standard'])}
{''.join(f'<tabs>{t}</tabs>' for t in tabs)}
<uiType>Lightning</uiType>
<workspaceConfig>{''.join(f'<mappings><tab>{t}</tab></mappings>' for t in tabs)}</workspaceConfig>
</CustomApplication>""")

# ---------------- Reports, report type, dashboard (CMP-071..075, 087, 088, 091)
w("reports/Maintenance_Management_Reports.reportFolder-meta.xml", f"<ReportFolder {NS}><folderShares><accessLevel>View</accessLevel><sharedTo>Maintenance_Supervisors_Managers</sharedTo><sharedToType>Group</sharedToType></folderShares><name>Maintenance Management Reports</name></ReportFolder>")
w("dashboards/Maintenance_Management_Dashboards.dashboardFolder-meta.xml", f"<DashboardFolder {NS}><folderShares><accessLevel>View</accessLevel><sharedTo>Maintenance_Supervisors_Managers</sharedTo><sharedToType>Group</sharedToType></folderShares><name>Maintenance Management Dashboards</name></DashboardFolder>")
RTF = "<criteriaItems><column>RECORDTYPE</column><columnToColumn>false</columnToColumn><isUnlocked>true</isUnlocked><operator>equals</operator><value>Case.Maintenance_Request</value></criteriaItems>"
OPEN = "<criteriaItems><column>STATUS</column><columnToColumn>false</columnToColumn><isUnlocked>true</isUnlocked><operator>notEqual</operator><value>Resolved,Closed</value></criteriaItems>"
def crit(col, op, val): return f"<criteriaItems><column>{col}</column><columnToColumn>false</columnToColumn><isUnlocked>true</isUnlocked><operator>{op}</operator><value>{val}</value></criteriaItems>"
def report(dev, name, cols, filters, fmt="Tabular", group=None, rtype="CaseList", sort=None, desc=""):
    c = "".join(f"<columns>{'<aggregateTypes>'+a+'</aggregateTypes>' if a else ''}<field>{f}</field></columns>" for f,a in cols)
    g = f"<groupingsDown><dateGranularity>Day</dateGranularity><field>{group}</field><sortOrder>Asc</sortOrder></groupingsDown>" if group else ""
    so = f"<sortColumn>{sort[0]}</sortColumn><sortOrder>{sort[1]}</sortOrder>" if sort else ""
    tf = "<timeFrameFilter><dateColumn>CREATED_DATEONLY</dateColumn><interval>INTERVAL_CUSTOM</interval></timeFrameFilter>" if rtype=="CaseList" else "<timeFrameFilter><dateColumn>Case$CreatedDate</dateColumn><interval>INTERVAL_CUSTOM</interval></timeFrameFilter>"
    scope = "<scope>organization</scope>" if rtype=="CaseList" else "<scope>organization</scope>"
    w(f"reports/Maintenance_Management_Reports/{dev}.report-meta.xml",
      f"<Report {NS}>{c}<description>{esc(desc)}</description><filter>{''.join(filters)}</filter><format>{fmt}</format>{g}<name>{esc(name)}</name><reportType>{rtype}</reportType>{scope}<showDetails>true</showDetails><showGrandTotal>true</showGrandTotal><showSubTotals>true</showSubTotals>{so}{tf}</Report>")
report("Open_Requests_by_Representative","Open Requests by Representative",[("CASE_NUMBER",None),("SUBJECT",None),("STATUS",None),("Case.Issue_Category__c",None),("Case.Maintenance_Team__c",None),("CREATED_DATEONLY",None)],
       [RTF,OPEN],"Summary","OWNER",desc="CMP-072. Open requests grouped by current owner.")
report("Open_Requests_by_Maintenance_Team","Open Requests by Maintenance Team",[("CASE_NUMBER",None),("SUBJECT",None),("STATUS",None),("OWNER",None),("CREATED_DATEONLY",None)],
       [RTF,OPEN,crit("Case.Maintenance_Team__c","notEqual","")],"Summary","Case.Maintenance_Team__c",desc="CMP-073. Open requests grouped by maintenance team.")
report("Overdue_Maintenance_Requests","Overdue Maintenance Requests",[("CASE_NUMBER",None),("SUBJECT",None),("STATUS",None),("Case.Issue_Category__c",None),("OWNER",None),("CREATED_DATEONLY",None),("Case.Escalation_Due__c",None),("Case.Is_Escalated__c",None)],
       [RTF,crit("Case.Is_Overdue__c","equals","1")],"Summary","Case.Maintenance_Team__c",sort=("Case.Escalation_Due__c","Asc"),desc="CMP-074. Unresolved more than 5 days after submission, grouped by team (summary so the dashboard metric can use it).")
report("Customer_Satisfaction_Ratings","Customer Satisfaction Ratings",[("CASE_NUMBER",None),("SUBJECT",None),("CONTACT.NAME",None),("STATUS",None),("CLOSED_DATEONLY",None),("Case.Satisfaction_Rating__c","Average")],
       [RTF,crit("Case.Satisfaction_Rating__c","notEqual","")],"Summary","OWNER",sort=("CLOSED_DATEONLY","Desc"),desc="CMP-091. Rated requests with average rating, grouped by representative.")
w("reportTypes/Case_with_Request_Assignments.reportType-meta.xml", f"""<ReportType {NS}><baseObject>Case</baseObject><category>cases</category><deployed>true</deployed><description>CMP-087. Cases with their assignment periods.</description>
<join><outerJoin>false</outerJoin><relationship>Request_Assignments__r</relationship></join><label>Cases with Request Assignments</label>
<sections>{''.join(f'<columns><checkedByDefault>true</checkedByDefault><field>{f}</field><table>Case</table></columns>' for f in ['CaseNumber','Subject','Status','ClosedDate','CreatedDate'])}<masterLabel>Cases</masterLabel></sections>
<sections>{''.join(f'<columns><checkedByDefault>true</checkedByDefault><field>{f}</field><table>Case.Request_Assignments__r</table></columns>' for f in ['Name','Assignment_Type__c','Assignee_User__c','Team__c','Start__c','End__c','Duration_Hours__c'])}<masterLabel>Request Assignments</masterLabel></sections>
</ReportType>""")
c2 = lambda col, op, val: f"<criteriaItems><column>{col}</column><columnToColumn>false</columnToColumn><isUnlocked>true</isUnlocked><operator>{op}</operator><value>{val}</value></criteriaItems>"
w("reports/Maintenance_Management_Reports/Resolution_Time_by_Assignment.report-meta.xml", f"""<Report {NS}>
<columns><field>Case$CaseNumber</field></columns><columns><field>Case.Request_Assignments__r$Start__c</field></columns><columns><field>Case.Request_Assignments__r$End__c</field></columns>
<columns><aggregateTypes>Sum</aggregateTypes><aggregateTypes>Average</aggregateTypes><field>Case.Request_Assignments__r$Duration_Hours__c</field></columns>
<description>CMP-088. Completed assignment periods by type, assignee and team.</description>
<filter>{c2("Case.Request_Assignments__r$End__c","notEqual","")}</filter><format>Summary</format>
<groupingsDown><dateGranularity>Day</dateGranularity><field>Case.Request_Assignments__r$Assignment_Type__c</field><sortOrder>Asc</sortOrder></groupingsDown>
<groupingsDown><dateGranularity>Day</dateGranularity><field>Case.Request_Assignments__r$Assignee_User__c</field><sortOrder>Asc</sortOrder></groupingsDown>
<groupingsDown><dateGranularity>Day</dateGranularity><field>Case.Request_Assignments__r$Team__c</field><sortOrder>Asc</sortOrder></groupingsDown>
<name>Resolution Time by Assignment</name><reportType>Case_with_Request_Assignments__c</reportType><scope>organization</scope><showDetails>true</showDetails><showGrandTotal>true</showGrandTotal><showSubTotals>true</showSubTotals>
<timeFrameFilter><dateColumn>Case$CreatedDate</dateColumn><interval>INTERVAL_CUSTOM</interval></timeFrameFilter>
</Report>""")
def dcomp(ctype, header, report, col, row, colspan=6, rowspan=8, extra="", auto=True, bands=("5","15","#C23934","#54C254")):
    ind = f"<indicatorBreakpoint1>{bands[0]}</indicatorBreakpoint1><indicatorBreakpoint2>{bands[1]}</indicatorBreakpoint2><indicatorHighColor>{bands[2]}</indicatorHighColor><indicatorLowColor>{bands[3]}</indicatorLowColor><indicatorMiddleColor>#FFB75D</indicatorMiddleColor>"
    return f"""<dashboardGridComponents><colSpan>{colspan}</colSpan><columnIndex>{col}</columnIndex><dashboardComponent><autoselectColumnsFromReport>{"true" if auto else "false"}</autoselectColumnsFromReport>{extra}<componentType>{ctype}</componentType><displayUnits>Auto</displayUnits><header>{esc(header)}</header>{ind if ctype=="Metric" else ""}<report>Maintenance_Management_Reports/{report}</report>{"<sortBy>RowValueDescending</sortBy>" if ctype=="Bar" else ""}</dashboardComponent><rowIndex>{row}</rowIndex><rowSpan>{rowspan}</rowSpan></dashboardGridComponents>"""
w("dashboards/Maintenance_Management_Dashboards/Maintenance_Manager_Workload.dashboard-meta.xml", f"""<Dashboard {NS}>
<backgroundEndColor>#FFFFFF</backgroundEndColor><backgroundFadeDirection>Diagonal</backgroundFadeDirection><backgroundStartColor>#FFFFFF</backgroundStartColor><chartTheme>light</chartTheme><colorPalette>unity</colorPalette>
<dashboardGridLayout>
{dcomp("Bar","Open requests by representative","Open_Requests_by_Representative",0,0,extra="<chartAxisRange>Auto</chartAxisRange>")}
{dcomp("Bar","Open requests by maintenance team","Open_Requests_by_Maintenance_Team",6,0,extra="<chartAxisRange>Auto</chartAxisRange>")}
{dcomp("Metric","Overdue requests","Overdue_Maintenance_Requests",0,8,4,4)}
{dcomp("Metric","Average satisfaction rating (1-5)","Customer_Satisfaction_Ratings",4,8,4,4,extra="<chartSummary><aggregate>Average</aggregate><axisBinding>y</axisBinding><column>Case.Satisfaction_Rating__c</column></chartSummary>",auto=False,bands=("2.5","3.5","#54C254","#C23934"))}
{dcomp("Bar","Overdue requests by team","Overdue_Maintenance_Requests",8,8,4,4,extra="<chartAxisRange>Auto</chartAxisRange>")}
<numberOfColumns>12</numberOfColumns><rowHeight>36</rowHeight></dashboardGridLayout>
<dashboardType>LoggedInUser</dashboardType><isGridLayout>true</isGridLayout><textColor>#000000</textColor><title>Maintenance Manager Workload</title><titleColor>#000000</titleColor><titleSize>12</titleSize>
</Dashboard>""")
print("ui/security generated")
