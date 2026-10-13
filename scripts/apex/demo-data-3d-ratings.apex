// Step 3d: ratings (5 stays resolved; 2 closes and opens a follow-up) and remaining statuses
String suffix = '@reelestate.' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
Id chloe = [SELECT Id FROM User WHERE Username = :('chloe' + suffix)].Id;
List<String> order = new List<String>{ 'priya.sharma@example.com|Plumbing', 'james.wilson@example.com|Electrical', 'mei.chen@example.com|Heating_Cooling', 'tom.baker@example.com|Pest_Control',
    'priya.sharma@example.com|Appliances', 'james.wilson@example.com|General', 'mei.chen@example.com|Structural', 'tom.baker@example.com|Plumbing' };
Map<Integer, Case> c = new Map<Integer, Case>();
for (Case x : [SELECT Id, SuppliedEmail, Issue_Category__c, Status FROM Case WHERE SuppliedEmail LIKE '%@example.com' AND ParentId = null]) {
    Integer k = order.indexOf(x.SuppliedEmail + '|' + x.Issue_Category__c); if (k >= 0) c.put(k, x);
}
update new Case(Id = c.get(4).Id, Status = 'Resolved');
update new Case(Id = c.get(4).Id, Satisfaction_Rating__c = 5);
update new Case(Id = c.get(5).Id, Status = 'Resolved');
update new Case(Id = c.get(5).Id, Satisfaction_Rating__c = 2);
update new Case(Id = c.get(6).Id, Status = 'Under Review');
update new Case(Id = c.get(7).Id, Status = 'Assigned', Maintenance_Team__c = 'Plumbing_Team');
System.debug('DEMO_OK step d followups=' + [SELECT COUNT() FROM Case WHERE ParentId = :c.get(5).Id]);
