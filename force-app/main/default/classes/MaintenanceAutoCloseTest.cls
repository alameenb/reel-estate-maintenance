@IsTest
private class MaintenanceAutoCloseTest {
    @IsTest static void satisfiedCasesStayResolvedBeforeSixWeeks() {
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', TestDataFactory.createAccountWithContact(true).Id, true);
        for (Case c : cs) { c.Status = 'Resolved'; }
        update cs;
        Test.startTest();
        for (Integer i = 0; i < cs.size(); i++) { cs[i].Satisfaction_Rating__c = 3 + Math.mod(i, 3); }
        update cs;
        Test.stopTest();
        Assert.areEqual(200, [SELECT COUNT() FROM Case WHERE Id IN :cs AND Status = 'Resolved' AND Satisfaction_Response_Date__c != NULL]);
    }

    @IsTest static void notResolvedMeansNoResponseDate() {
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, true);
        cs[0].Satisfaction_Rating__c = 4;
        update cs;
        Assert.isNull([SELECT Satisfaction_Response_Date__c FROM Case WHERE Id = :cs[0].Id].Satisfaction_Response_Date__c);
    }

    @IsTest static void autoCloseDaysConfigured() {
        Assert.areEqual(42, MaintenanceConstants.settings().Auto_Close_Days__c, 'Six weeks');
    }
}
