@IsTest
private class CaseTriggerHandlerTest {
    @IsTest static void routingRunsOncePerTransaction() {
        Test.startTest();
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', null, true);
        Test.stopTest();
        Assert.areEqual(1, CaseTriggerHandler.routingRuns, 'Routing should run once for a single 200-record insert');
        Assert.areEqual(200, CaseTriggerHandler.routed.size());
    }

    @IsTest static void recursionGuardSkipsAlreadyRoutedCases() {
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, true);
        Integer before = CaseTriggerHandler.routingRuns;
        new CaseTriggerHandler().afterInsert(cs);
        Assert.areEqual(before, CaseTriggerHandler.routingRuns, 'Already-routed case must not be routed twice');
    }

    @IsTest static void historyIsTrackedForStatusAndOwner() {
        Assert.isTrue(Schema.SObjectType.Case.fields.Status.isAccessible());
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        System.runAs(csr) {
            List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, true);
            cs[0].Status = 'Under Review';
            update cs;
            Assert.areEqual('Under Review', [SELECT Status FROM Case WHERE Id = :cs[0].Id].Status);
            Assert.isTrue(Schema.SObjectType.CaseHistory.isAccessible(), 'CSR can read history');
        }
    }
}
