// Step 3c: information request, resolution and escalation timing
String suffix = '@reelestate.' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
Id chloe = [SELECT Id FROM User WHERE Username = :('chloe' + suffix)].Id;
List<String> order = new List<String>{ 'priya.sharma@example.com|Plumbing', 'james.wilson@example.com|Electrical', 'mei.chen@example.com|Heating_Cooling', 'tom.baker@example.com|Pest_Control',
    'priya.sharma@example.com|Appliances', 'james.wilson@example.com|General', 'mei.chen@example.com|Structural', 'tom.baker@example.com|Plumbing' };
Map<Integer, Case> c = new Map<Integer, Case>();
for (Case x : [SELECT Id, SuppliedEmail, Issue_Category__c, Status FROM Case WHERE SuppliedEmail LIKE '%@example.com' AND ParentId = null]) {
    Integer k = order.indexOf(x.SuppliedEmail + '|' + x.Issue_Category__c); if (k >= 0) c.put(k, x);
}
update new Case(Id = c.get(1).Id, Status = 'Under Review');
insert new FeedItem(ParentId = c.get(1).Id, Type = 'TextPost', Visibility = 'AllUsers', Body = 'Information requested: Please send a photo of the power point and tell us whether the switch is on when it sparks.');
update new Case(Id = c.get(1).Id, Status = 'Awaiting Customer Information');
update new Case(Id = c.get(2).Id, Status = 'In Progress', Maintenance_Team__c = 'General_Maintenance');
update new Case(Id = c.get(2).Id, Status = 'Resolved');
update new Case(Id = c.get(3).Id, Escalation_Due__c = Datetime.now().addMinutes(4));
System.debug('DEMO_OK step c');
