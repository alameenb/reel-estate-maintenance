#!/usr/bin/env python3
"""Customises the retrieved Experience Cloud site (Customer Service template) for the maintenance portal:
public intake page (CMP-052), My Requests (CMP-057), request detail with rating flow (CMP-019/117),
login-only everywhere else (CMP-125), customer membership, sharing set (CMP-018)."""
import json, pathlib, uuid, re
ROOT = pathlib.Path(__file__).resolve().parent.parent / "force-app/main/default"
EXP = ROOT / "experiences/Maintenance_Customer_Portal1"
def load(p): return json.loads(p.read_text())
def save(p, d): p.write_text(json.dumps(d, indent=2) + "\n")
def uid(seed): return str(uuid.uuid5(uuid.NAMESPACE_URL, "reel-estate/" + seed))
def comp(name, attrs, seed): return {"componentAttributes": attrs, "componentName": name, "id": uid(seed), "renderPriority": "NEUTRAL", "renditionMap": {}, "type": "component"}

main = load(EXP / "config/mainAppPage.json") if (EXP / "config/mainAppPage.json").exists() else None
main_id = next(load(p)["id"] for p in (EXP / "config").glob("*.json") if load(p).get("label") == "main")

# 1. Public intake page
route = {"activeViewId": uid("view-intake"), "appPageId": main_id, "configurationTags": [], "devName": "Request_Maintenance", "id": uid("route-intake"),
         "label": "Request Maintenance", "pageAccess": "Public", "routeType": "custom-request-maintenance", "type": "route", "urlPrefix": "request-maintenance"}
save(EXP / "routes/requestMaintenance.json", route)
view = {"appPageId": main_id, "componentName": "siteforce:sldsOneColLayout", "dataProviders": [], "id": uid("view-intake"), "label": "Request Maintenance",
        "regions": [{"id": uid("r-h"), "regionName": "header", "type": "region"},
                    {"components": [comp("c:maintenanceRequestIntake", {}, "c-intake")], "id": uid("r-c"), "regionName": "content", "type": "region"},
                    {"id": uid("r-f"), "regionName": "footer", "type": "region"},
                    {"components": [comp("forceCommunity:seoAssistant", {"customHeadTags": "", "description": "Submit a maintenance request to Reel Estate", "title": "Request Maintenance"}, "seo-intake")],
                     "id": uid("r-s"), "regionName": "sfdcHiddenRegion", "type": "region"}],
        "themeLayoutType": "Inner", "type": "view", "viewType": "custom-request-maintenance"}
save(EXP / "views/requestMaintenance.json", view)

# 2. Site available to guests, but every page except intake/error requires login
for p in (EXP / "config").glob("*.json"):
    d = load(p)
    if d.get("type") == "site": d["isAvailableToGuests"] = True; save(p, d)
PUBLIC = {"Request_Maintenance", "Error", "Service_Not_Available", "Too_Many_Requests", "Check_Password", "Forgot_Password", "Login", "Login_Error", "Register"}
for p in (EXP / "routes").glob("*.json"):
    d = load(p)
    # Only standard content pages carry a page-access setting; record/object pages are governed by
    # object access, and the guest profile has none (guest can call the intake controller only).
    if d.get("appPageId") != main_id or "pageAccess" not in d: continue
    d["pageAccess"] = "Public" if d.get("devName") in PUBLIC else "RequiresLogin"
    save(p, d)

# 3. Home = the customer's own requests + call to action
home = load(EXP / "views/home.json")
for r in home["regions"]:
    if r["regionName"] == "header":
        r["components"] = [comp("forceCommunity:richTextInline", {"richTextValue": "<h1 style=\"font-size:28px\">Your maintenance requests</h1><p>Track progress, reply to our team and rate completed work.</p>"}, "home-head")]
    elif r["regionName"] == "featured": r["components"] = []
    elif r["regionName"] == "content":
        r["components"] = [comp("forceCommunity:objectHome", {"enableInlineEdit": False, "filterName": "Portal_Maintenance_Requests", "layout": "FULL", "pageSize": 25, "scope": "Case",
            "showActionBar": False, "showChartsPanel": False, "showDisplay": "showall", "showFilterPanel": False, "showImageIcon": True, "showManualRefreshButton": True,
            "showObjectName": True, "showPinnedList": False, "showSearchBar": True}, "home-list")]
    elif r["regionName"] == "sidebar":
        r["components"] = [comp("forceCommunity:richTextInline", {"richTextValue": "<h2>Something need fixing?</h2><p><a href=\"/maintenance/s/request-maintenance\">Submit a new maintenance request</a></p>"}, "home-cta")]
save(EXP / "views/home.json", home)

# 4. Case list defaults to My Requests
cl = load(EXP / "views/caseList.json")
for r in cl["regions"]:
    for c in r.get("components", []) or []:
        if c["componentName"] == "forceCommunity:objectHome":
            c["componentAttributes"].update({"filterName": "Portal_Maintenance_Requests", "showChartsPanel": False, "enableInlineEdit": False})
save(EXP / "views/caseList.json", cl)

# 5. Case detail: rating flow above the tabs
cd = load(EXP / "views/caseDetail.json")
for r in cd["regions"]:
    if r["regionName"] == "content":
        r["components"] = [c for c in r["components"] if c["componentName"] != "forceCommunity:flowCommunity"]
        args = json.dumps([{"label": "recordId", "dataType": "String", "supportsRecordId": True, "value": "{!recordId}"}])
        r["components"].insert(1, comp("forceCommunity:flowCommunity", {"flowArguments": args, "flowName": "Maintenance_Rate_Request", "flowLayout": "oneColumn"}, "rate-flow"))
save(EXP / "views/caseDetail.json", cd)

# 6. Navigation
nav = ROOT / "navigationMenus/SFDC_Default_Navigation_Maintenance_Customer_Portal.navigationMenu-meta.xml"
nav.write_text("""<?xml version="1.0" encoding="UTF-8"?>
<NavigationMenu xmlns="http://soap.sforce.com/2006/04/metadata">
    <container>Maintenance Customer Portal</container>
    <containerType>Network</containerType>
    <label>Default Navigation</label>
    <navigationMenuItem><label>My Requests</label><position>0</position><publiclyAvailable>false</publiclyAvailable><target>Case</target><type>SalesforceObject</type></navigationMenuItem>
    <navigationMenuItem><label>Request Maintenance</label><position>1</position><publiclyAvailable>true</publiclyAvailable><target>/request-maintenance</target><type>InternalLink</type></navigationMenuItem>
</NavigationMenu>
""")

# 7. Network: customers are members; go live
net = ROOT / "networks/Maintenance Customer Portal.network-meta.xml"
s = net.read_text()
s = re.sub(r"<networkMemberGroups>.*?</networkMemberGroups>", "<networkMemberGroups><profile>admin</profile><profile>customer community user</profile><profile>customer community login user</profile></networkMemberGroups>", s, flags=re.S)
s = s.replace("<status>UnderConstruction</status>", "<status>Live</status>")
net.write_text(s)

# 8. Sharing set (CMP-018): customers see and update only requests where they are the contact
(ROOT / "sharingSets").mkdir(exist_ok=True)
(ROOT / "sharingSets/Customer_Case_Access.sharingSet-meta.xml").write_text("""<?xml version="1.0" encoding="UTF-8"?>
<SharingSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <accessMappings><accessLevel>Edit</accessLevel><object>Case</object><objectField>Contact</objectField><userField>Contact</userField></accessMappings>
    <description>CMP-018. Portal customers see their own maintenance requests (ContactId = their contact). Edit is needed for the rating flow; field access limits what they can change.</description>
    <name>Customer Case Access</name>
    <profiles>customer community user</profiles>
    <profiles>customer community login user</profiles>
</SharingSet>
""")
print("portal customised")
