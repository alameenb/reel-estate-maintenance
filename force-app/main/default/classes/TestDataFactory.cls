/** CMP-009. Shared test data. No assertions, no hardcoded Ids. */
@IsTest
public class TestDataFactory {
    private static Integer seq = 0;
    private static String uniq() { seq++; return String.valueOf(Datetime.now().getTime()) + seq + Integer.valueOf(Math.random() * 100000); }

    public static Id maintenanceRecordTypeId() { return MaintenanceConstants.recordTypeId(); }

    public static Contact createAccountWithContact(Boolean doInsert) { return createAccountWithContact(doInsert, null); }

    public static Contact createAccountWithContact(Boolean doInsert, Id accountOwnerId) {
        String u = uniq();
        Account a = new Account(Name = 'Customer ' + u);
        if (accountOwnerId != null) { a.OwnerId = accountOwnerId; }
        insert a;
        Contact c = new Contact(AccountId = a.Id, FirstName = 'Test', LastName = 'Customer' + u, Email = 'cust' + u + '@example.com');
        if (doInsert) { Database.DMLOptions o = new Database.DMLOptions(); o.DuplicateRuleHeader.allowSave = true; Database.insert(c, o); }
        return c;
    }

    public static Property__c createProperty(String street, String postcode) {
        Property__c p = new Property__c(Name = street, Street__c = street, City__c = 'Melbourne', Postal_Code__c = postcode);
        insert p;
        return p;
    }

    public static List<Case> createMaintenanceCases(Integer count, String issueCategory, Id contactId, Boolean doInsert) {
        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < count; i++) {
            cases.add(new Case(RecordTypeId = maintenanceRecordTypeId(), Subject = 'Test request ' + i, Status = 'New',
                Issue_Category__c = issueCategory, ContactId = contactId, Origin = 'Web'));
        }
        if (doInsert) { insert cases; }
        return cases;
    }

    public static User createUserWithPermissionSet(String permSetName, String profileName) {
        return createInternalUser(new List<String>{ permSetName }, profileName, null);
    }

    public static User createInternalUser(List<String> permSetNames, String profileName, Id roleId) {
        String u = uniq();
        Profile p = [SELECT Id FROM Profile WHERE Name = :(profileName == null ? 'Minimum Access - Salesforce' : profileName) LIMIT 1];
        User usr = new User(ProfileId = p.Id, Username = 'u' + u + '@reelestate.test', Email = 'u' + u + '@example.com',
            LastName = 'User' + u.right(6), Alias = 'u' + u.right(6), TimeZoneSidKey = 'Australia/Sydney', LocaleSidKey = 'en_AU',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', UserRoleId = roleId);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert usr;
            assign(usr.Id, permSetNames);
        }
        return usr;
    }

    public static void assign(Id userId, List<String> permSetNames) {
        if (permSetNames == null || permSetNames.isEmpty()) { return; }
        List<PermissionSetAssignment> psa = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :permSetNames]) { psa.add(new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id)); }
        insert psa;
    }

    public static void addToGroup(Id userId, String groupDeveloperName) {
        Group g = [SELECT Id FROM Group WHERE DeveloperName = :groupDeveloperName LIMIT 1];
        System.runAs(new User(Id = UserInfo.getUserId())) { insert new GroupMember(GroupId = g.Id, UserOrGroupId = userId); }
    }

    /** Profile for Experience Cloud customers, or null when the org has no community licence. */
    public static Profile portalProfile() {
        List<Profile> ps = [SELECT Id FROM Profile WHERE UserLicense.Name IN ('Customer Community', 'Customer Community Login', 'Customer Community Plus', 'Customer Community Plus Login') ORDER BY Name LIMIT 1];
        return ps.isEmpty() ? null : ps[0];
    }

    /** An account owner with a role, required for portal users. */
    public static User createAccountOwnerWithRole() {
        UserRole r;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            r = new UserRole(Name = 'Maintenance Test Role ' + uniq().right(6));
            insert r;
        }
        return createInternalUser(new List<String>(), 'System Administrator', r.Id);
    }

    /** Creates a portal user for the contact (whose account must be owned by a user with a role). */
    public static User createPortalUser(Contact c, List<String> permSetNames) {
        Profile p = portalProfile();
        if (p == null) { return null; }
        String u = uniq();
        User usr = new User(ProfileId = p.Id, ContactId = c.Id, Username = 'p' + u + '@reelestate.test', Email = c.Email,
            LastName = c.LastName, FirstName = c.FirstName, Alias = 'p' + u.right(6), TimeZoneSidKey = 'Australia/Sydney',
            LocaleSidKey = 'en_AU', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert usr;
            assign(usr.Id, permSetNames);
        }
        return usr;
    }

    /** Portal customer fixture: owner-with-role, account, contact, portal user. Returns null when portals are unavailable. */
    public static Map<String, SObject> createPortalCustomer(List<String> permSetNames) {
        if (portalProfile() == null) { return null; }
        User owner = createAccountOwnerWithRole();
        Contact c;
        System.runAs(owner) { c = createAccountWithContact(true, owner.Id); }
        User portal = createPortalUser(c, permSetNames);
        return new Map<String, SObject>{ 'contact' => c, 'user' => portal, 'owner' => owner };
    }
}
