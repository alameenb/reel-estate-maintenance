// Step 3a: demo maintenance requests, created through the real intake service, then moved through the lifecycle.
// Creates up to 3 missing requests per run (flows and routing make each intake query-heavy); run until it reports 0 created.
Set<String> existing = new Set<String>();
for (Case e : [SELECT SuppliedEmail, Issue_Category__c FROM Case WHERE SuppliedEmail LIKE '%@example.com' AND ParentId = null]) existing.add(e.SuppliedEmail + '|' + e.Issue_Category__c);
String suffix = '@reelestate.' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
Id chloe = [SELECT Id FROM User WHERE Username = :('chloe' + suffix)].Id;
Id escQueue = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Maintenance_Escalation'].Id;
List<List<String>> reqs = new List<List<String>>{
    // name, email, phone, street, city, postcode, category, description
    new List<String>{ 'Priya Sharma', 'priya.sharma@example.com', '0412 345 678', '12 Station Street', 'Officer', '3809', 'Plumbing', 'The kitchen tap is leaking under the sink and the cupboard floor is getting wet.' },
    new List<String>{ 'James Wilson', 'james.wilson@example.com', '0423 456 789', '4/22 Princes Highway', 'Pakenham', '3810', 'Electrical', 'The power point in the main bedroom sparks when anything is plugged in.' },
    new List<String>{ 'Mei Chen', 'mei.chen@example.com', '0434 567 890', '9 Bluebell Court', 'Berwick', '3806', 'Heating_Cooling', 'The split system in the living room runs but is not cooling.' },
    new List<String>{ 'Tom Baker', 'tom.baker@example.com', '0445 678 901', '31 Grasstree Road', 'Clyde', '3978', 'Pest_Control', 'Signs of termites along the garage skirting boards.' },
    new List<String>{ 'Priya Sharma', 'priya.sharma@example.com', '0412 345 678', '12 Station Street', 'Officer', '3809', 'Appliances', 'The dishwasher is not draining at the end of the cycle.' },
    new List<String>{ 'James Wilson', 'james.wilson@example.com', '0423 456 789', '4/22 Princes Highway', 'Pakenham', '3810', 'General', 'The front door lock sticks and is hard to turn.' },
    new List<String>{ 'Mei Chen', 'mei.chen@example.com', '0434 567 890', '9 Bluebell Court', 'Berwick', '3806', 'Structural', 'A diagonal crack has appeared in the living room wall above the window.' },
    new List<String>{ 'Tom Baker', 'tom.baker@example.com', '0445 678 901', '31 Grasstree Road', 'Clyde', '3978', 'Plumbing', 'The hot water system is leaking from the relief valve.' } };
List<Id> ids = new List<Id>();
Integer i = 0;
for (List<String> r : reqs) {
    if (existing.contains(r[1] + '|' + r[6]) || ids.size() >= 3) { i++; continue; }
    MaintenanceRequestIntakeService.IntakeRequest x = new MaintenanceRequestIntakeService.IntakeRequest();
    x.name = r[0]; x.email = r[1]; x.phone = r[2]; x.street = r[3]; x.city = r[4]; x.postalCode = r[5]; x.category = r[6]; x.description = r[7];
    x.preferredAppointment = Datetime.newInstance(Date.today().addDays(2 + i), Time.newInstance(9 + Math.mod(i, 4), 0, 0, 0));
    String ref = MaintenanceRequestIntakeService.submit(x, null);
    ids.add([SELECT Id FROM Case WHERE CaseNumber = :ref].Id);
    i++;
}
System.debug('DEMO_OK requests=' + ids.size());
