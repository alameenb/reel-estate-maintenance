// Step 2: Experience Cloud logins for two demo customers (setup objects, separate transaction).
Profile p = [SELECT Id FROM Profile WHERE Name = 'Customer Community User'];
String admEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
String suffix = '@reelestate.' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
List<User> us = new List<User>();
for (Contact c : [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Email IN ('priya.sharma@example.com', 'james.wilson@example.com')]) {
    String uname = c.FirstName.toLowerCase() + '.portal' + suffix;
    if ([SELECT COUNT() FROM User WHERE Username = :uname] > 0) continue;
    us.add(new User(ProfileId = p.Id, ContactId = c.Id, Username = uname, Email = admEmail, FirstName = c.FirstName, LastName = c.LastName,
        Alias = c.FirstName.left(4).toLowerCase() + 'p', CommunityNickname = c.FirstName + c.LastName.left(1) + 'Portal',
        TimeZoneSidKey = 'Australia/Sydney', LocaleSidKey = 'en_AU', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US'));
}
insert us;
List<PermissionSetAssignment> psa = new List<PermissionSetAssignment>();
for (User u : [SELECT Id FROM User WHERE Username LIKE :('%.portal' + suffix)]) {
    for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN ('Maintenance_Portal_Customer', 'Maintenance_Portal_Rating')]) {
        if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :u.Id AND PermissionSetId = :ps.Id] == 0) psa.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
    }
}
insert psa;
System.debug('DEMO_OK portal users=' + [SELECT COUNT() FROM User WHERE Username LIKE :('%.portal' + suffix)]);
