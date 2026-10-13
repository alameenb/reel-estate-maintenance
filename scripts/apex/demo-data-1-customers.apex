// Step 1: demo customers and properties (all fictional). Safe to re-run.
Database.DMLOptions dml = new Database.DMLOptions(); dml.DuplicateRuleHeader.allowSave = true;
List<List<String>> people = new List<List<String>>{
    new List<String>{ 'Priya', 'Sharma', 'priya.sharma@example.com', '0412 345 678' },
    new List<String>{ 'James', 'Wilson', 'james.wilson@example.com', '0423 456 789' },
    new List<String>{ 'Mei', 'Chen', 'mei.chen@example.com', '0434 567 890' },
    new List<String>{ 'Tom', 'Baker', 'tom.baker@example.com', '0445 678 901' } };
Map<String, Contact> byEmail = new Map<String, Contact>();
for (Contact c : [SELECT Id, Email, AccountId FROM Contact WHERE Email LIKE '%@example.com']) byEmail.put(c.Email, c);
for (List<String> p : people) {
    if (byEmail.containsKey(p[2])) continue;
    Account a = new Account(Name = p[0] + ' ' + p[1]);
    Database.insert(a, dml);
    Contact c = new Contact(AccountId = a.Id, FirstName = p[0], LastName = p[1], Email = p[2], Phone = p[3]);
    Database.insert(c, dml);
    byEmail.put(p[2], c);
}
List<List<String>> props = new List<List<String>>{
    new List<String>{ '12 Station Street', 'Officer', '3809' }, new List<String>{ '4/22 Princes Highway', 'Pakenham', '3810' },
    new List<String>{ '9 Bluebell Court', 'Berwick', '3806' }, new List<String>{ '31 Grasstree Road', 'Clyde', '3978' } };
Map<String, Property__c> pByStreet = new Map<String, Property__c>();
for (Property__c p : [SELECT Id, Street__c FROM Property__c]) pByStreet.put(p.Street__c, p);
for (List<String> p : props) {
    if (pByStreet.containsKey(p[0])) continue;
    Property__c pr = new Property__c(Name = p[0], Street__c = p[0], City__c = p[1], Postal_Code__c = p[2]);
    insert pr; pByStreet.put(p[0], pr);
}
List<List<String>> links = new List<List<String>>{
    new List<String>{ 'priya.sharma@example.com', '12 Station Street', 'Owner' }, new List<String>{ 'james.wilson@example.com', '4/22 Princes Highway', 'Tenant' },
    new List<String>{ 'mei.chen@example.com', '9 Bluebell Court', 'Owner' }, new List<String>{ 'mei.chen@example.com', '4/22 Princes Highway', 'Owner' },
    new List<String>{ 'tom.baker@example.com', '31 Grasstree Road', 'Owner' } };
for (List<String> l : links) {
    Id cid = byEmail.get(l[0]).Id, pid = pByStreet.get(l[1]).Id;
    if ([SELECT COUNT() FROM Property_Customer__c WHERE Contact__c = :cid AND Property__c = :pid] == 0)
        insert new Property_Customer__c(Contact__c = cid, Property__c = pid, Relationship__c = l[2]);
}
System.debug('DEMO_OK customers=' + byEmail.size() + ' properties=' + pByStreet.size());
