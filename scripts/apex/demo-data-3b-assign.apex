// Step 3b: assign to Chloe and progress the first requests
String suffix = '@reelestate.' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
Id chloe = [SELECT Id FROM User WHERE Username = :('chloe' + suffix)].Id;
List<String> order = new List<String>{ 'priya.sharma@example.com|Plumbing', 'james.wilson@example.com|Electrical', 'mei.chen@example.com|Heating_Cooling', 'tom.baker@example.com|Pest_Control',
    'priya.sharma@example.com|Appliances', 'james.wilson@example.com|General', 'mei.chen@example.com|Structural', 'tom.baker@example.com|Plumbing' };
Map<Integer, Case> c = new Map<Integer, Case>();
for (Case x : [SELECT Id, SuppliedEmail, Issue_Category__c, Status FROM Case WHERE SuppliedEmail LIKE '%@example.com' AND ParentId = null]) {
    Integer k = order.indexOf(x.SuppliedEmail + '|' + x.Issue_Category__c); if (k >= 0) c.put(k, x);
}
List<Id> mine = new List<Id>();
for (Integer k : new List<Integer>{ 0, 1, 2, 4, 5, 6, 7 }) mine.add(c.get(k).Id);
delete [SELECT Id FROM PendingServiceRouting WHERE WorkItemId IN :mine];
List<Case> upd = new List<Case>();
for (Id x : mine) upd.add(new Case(Id = x, OwnerId = chloe));
update upd;
update new Case(Id = c.get(0).Id, Status = 'Assigned', Maintenance_Team__c = 'Plumbing_Team');
update new Case(Id = c.get(0).Id, Status = 'In Progress', Appointment_DateTime__c = Datetime.newInstance(Date.today().addDays(1), Time.newInstance(10, 0, 0, 0)));
insert new FeedItem(ParentId = c.get(0).Id, Type = 'TextPost', Visibility = 'InternalUsers', Body = 'Plumber confirmed for tomorrow 10am. Bring a replacement mixer cartridge.');
System.debug('DEMO_OK step b');
