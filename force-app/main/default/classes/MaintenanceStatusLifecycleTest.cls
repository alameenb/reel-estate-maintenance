@IsTest
private class MaintenanceStatusLifecycleTest {
    static final List<String> LIFECYCLE = new List<String>{ 'New', 'Under Review', 'Awaiting Customer Information', 'Assigned', 'In Progress', 'Resolved', 'Closed' };

    @IsTest static void allLifecycleStatusesExistAndPersist() {
        Set<String> values = new Set<String>();
        for (Schema.PicklistEntry e : Case.Status.getDescribe().getPicklistValues()) { if (e.isActive()) { values.add(e.getValue()); } }
        Assert.isTrue(values.containsAll(LIFECYCLE), 'Missing lifecycle values: ' + values);
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, false);
        cs[0].OwnerId = csr.Id;
        insert cs;
        System.runAs(csr) {
            for (String s : LIFECYCLE) {
                Database.update(new Case(Id = cs[0].Id, Status = s), AccessLevel.USER_MODE);
                Assert.areEqual(s, [SELECT Status FROM Case WHERE Id = :cs[0].Id].Status);
            }
        }
    }

    @IsTest static void bulkAndOwnershipEnforced() {
        User csr1 = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        User csr2 = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', null, false);
        for (Case c : cs) { c.OwnerId = csr1.Id; }
        insert cs;
        System.runAs(csr1) {
            List<Case> changes = new List<Case>();
            for (Case c : cs) { changes.add(new Case(Id = c.Id, Status = 'Under Review')); }
            Database.update(changes, AccessLevel.USER_MODE);
        }
        Assert.areEqual(200, [SELECT COUNT() FROM Case WHERE Id IN :cs AND Status = 'Under Review']);
        System.runAs(csr2) {
            try { Database.update(new Case(Id = cs[0].Id, Status = 'Assigned'), AccessLevel.USER_MODE); Assert.fail('Other CSR cannot edit'); } catch (Exception e) { }
        }
    }
}
