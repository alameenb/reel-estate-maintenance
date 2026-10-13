// Demo users for the Reel Estate maintenance demo. Safe to re-run.
User admin = [SELECT Id, Email, UserRoleId FROM User WHERE Id = :UserInfo.getUserId()];
UserRole role;
List<UserRole> roles = [SELECT Id FROM UserRole WHERE DeveloperName = 'Reel_Estate_Management' LIMIT 1];
if (roles.isEmpty()) { role = new UserRole(Name = 'Reel Estate Management', DeveloperName = 'Reel_Estate_Management'); insert role; } else { role = roles[0]; }
if (admin.UserRoleId == null) { admin.UserRoleId = role.Id; update admin; }

String suffix = '@reelestate.' + UserInfo.getOrganizationId().left(15).toLowerCase() + '.demo';
Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
Map<String, User> wanted = new Map<String, User>{
    'chloe' => new User(FirstName = 'Chloe', LastName = 'Nguyen', Alias = 'cnguyen', Title = 'Customer Service Representative'),
    'marcus' => new User(FirstName = 'Marcus', LastName = 'Lee', Alias = 'mlee', Title = 'Maintenance Manager') };
List<User> toInsert = new List<User>();
for (String k : wanted.keySet()) {
    String uname = k + suffix;
    if ([SELECT COUNT() FROM User WHERE Username = :uname] > 0) { continue; }
    User u = wanted.get(k);
    u.Username = uname; u.Email = admin.Email; u.ProfileId = std.Id; u.UserRoleId = role.Id;
    u.TimeZoneSidKey = 'Australia/Sydney'; u.LocaleSidKey = 'en_AU'; u.EmailEncodingKey = 'UTF-8'; u.LanguageLocaleKey = 'en_US';
    toInsert.add(u);
}
insert toInsert;
Map<String, Id> ids = new Map<String, Id>();
for (User u : [SELECT Id, Username FROM User WHERE Username LIKE :('%' + suffix)]) { ids.put(u.Username.substringBefore('@'), u.Id); }
Map<String, List<String>> sets = new Map<String, List<String>>{
    'chloe' => new List<String>{ 'Maintenance_CSR', 'Maintenance_Property_User', 'Maintenance_Resolution_Confirmation' },
    'marcus' => new List<String>{ 'Maintenance_Supervisor_Manager', 'Maintenance_Manager_Insights', 'Maintenance_Property_User' } };
List<PermissionSetAssignment> psa = new List<PermissionSetAssignment>();
for (String k : sets.keySet()) {
    for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :sets.get(k)]) {
        if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :ids.get(k) AND PermissionSetId = :ps.Id] == 0) {
            psa.add(new PermissionSetAssignment(AssigneeId = ids.get(k), PermissionSetId = ps.Id));
        }
    }
}
insert psa;
// Admin: full access + supervisor group so the admin can demo everything
for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN ('Maintenance_CSR', 'Maintenance_Resolution_Confirmation', 'Maintenance_Request_Admin')]) {
    if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :admin.Id AND PermissionSetId = :ps.Id] == 0) { insert new PermissionSetAssignment(AssigneeId = admin.Id, PermissionSetId = ps.Id); }
}
Map<String, Id> groups = new Map<String, Id>();
for (Group g : [SELECT Id, DeveloperName FROM Group WHERE DeveloperName IN ('Maintenance_Supervisors_Managers', 'Maintenance_Team_Plumbing_Team')]) { groups.put(g.DeveloperName, g.Id); }
List<GroupMember> gms = new List<GroupMember>();
for (Id uid : new List<Id>{ ids.get('marcus') }) {
    if ([SELECT COUNT() FROM GroupMember WHERE GroupId = :groups.get('Maintenance_Supervisors_Managers') AND UserOrGroupId = :uid] == 0) gms.add(new GroupMember(GroupId = groups.get('Maintenance_Supervisors_Managers'), UserOrGroupId = uid));
    if ([SELECT COUNT() FROM GroupMember WHERE GroupId = :groups.get('Maintenance_Team_Plumbing_Team') AND UserOrGroupId = :uid] == 0) gms.add(new GroupMember(GroupId = groups.get('Maintenance_Team_Plumbing_Team'), UserOrGroupId = uid));
}
insert gms;
// Escalation queue members
Group escQ = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Maintenance_Escalation'];
if ([SELECT COUNT() FROM GroupMember WHERE GroupId = :escQ.Id AND UserOrGroupId = :ids.get('marcus')] == 0) insert new GroupMember(GroupId = escQ.Id, UserOrGroupId = ids.get('marcus'));
System.debug('DEMO_USERS ' + JSON.serialize(ids));
