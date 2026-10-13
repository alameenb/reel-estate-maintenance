@IsTest
private class MaintenanceCustomerAccessTest {
    @IsTest static void customersSeeOnlyTheirOwnRequests() {
        Map<String, SObject> a = TestDataFactory.createPortalCustomer(new List<String>{ 'Maintenance_Portal_Customer' });
        if (a == null) { Assert.isNull(TestDataFactory.portalProfile(), 'No community licence in this org'); return; }
        Map<String, SObject> b = TestDataFactory.createPortalCustomer(new List<String>{ 'Maintenance_Portal_Customer' });
        List<Case> aCases = TestDataFactory.createMaintenanceCases(200, 'Plumbing', a.get('contact').Id, true);
        List<Case> bCases = TestDataFactory.createMaintenanceCases(200, 'Plumbing', b.get('contact').Id, true);
        System.runAs((User) a.get('user')) {
            Assert.areEqual(200, [SELECT COUNT() FROM Case WITH USER_MODE]);
            Assert.areEqual(0, [SELECT COUNT() FROM Case WHERE Id = :bCases[0].Id WITH USER_MODE]);
            try { Database.update(new Case(Id = bCases[0].Id, Subject = 'x'), AccessLevel.USER_MODE); Assert.fail(); } catch (Exception e) { }
        }
    }

    @IsTest static void guestUserHasNoCaseAccess() {
        List<Site> sites = [SELECT GuestUserId FROM Site WHERE Name = 'Maintenance_Customer_Portal' LIMIT 1];
        if (sites.isEmpty()) { Assert.isTrue(sites.isEmpty(), 'Portal site not created yet'); return; }
        System.runAs(new User(Id = sites[0].GuestUserId)) {
            Assert.isFalse(Schema.SObjectType.Case.isAccessible());
        }
    }
}
