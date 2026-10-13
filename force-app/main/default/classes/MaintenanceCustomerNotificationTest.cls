@IsTest
private class MaintenanceCustomerNotificationTest {
    @IsTest static void creationStatusChangeAndResolution() {
        Contact c = TestDataFactory.createAccountWithContact(true);
        MaintenanceMessaging.emailsQueued = 0;
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', c.Id, true);
        Assert.areEqual(1, MaintenanceMessaging.emailsQueued, 'Acknowledgement on creation. ' + String.join(MaintenanceMessaging.log, '; '));
        cs[0].Status = 'In Progress';
        update cs;
        Assert.areEqual(2, MaintenanceMessaging.emailsQueued, 'Status change update');
        cs[0].Status = 'Resolved';
        update cs;
        Assert.areEqual(3, MaintenanceMessaging.emailsQueued, 'Resolved sends exactly one (no generic duplicate)');
    }

    @IsTest static void contactWithoutEmailDoesNotFail() {
        Contact c = TestDataFactory.createAccountWithContact(false);
        c.Email = null;
        insert c;
        MaintenanceMessaging.emailsQueued = 0;
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', c.Id, true);
        cs[0].Status = 'In Progress';
        update cs;
        Assert.areEqual(0, MaintenanceMessaging.emailsQueued);
    }

    @IsTest static void bulkStatusChanges() {
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', c.Id, true);
        MaintenanceMessaging.emailsQueued = 0;
        Test.startTest();
        for (Case x : cs) { x.Status = 'Under Review'; }
        update cs;
        Test.stopTest();
        Assert.areEqual(200, MaintenanceMessaging.emailsQueued);
    }

    @IsTest static void ratingRange() {
        List<Case> cs = TestDataFactory.createMaintenanceCases(4, 'Plumbing', null, true);
        cs[0].Satisfaction_Rating__c = 0; cs[1].Satisfaction_Rating__c = 6; cs[2].Satisfaction_Rating__c = 1; cs[3].Satisfaction_Rating__c = 5;
        List<Database.SaveResult> res = Database.update(cs, false);
        Assert.isFalse(res[0].isSuccess()); Assert.isFalse(res[1].isSuccess());
        Assert.isTrue(res[2].isSuccess()); Assert.isTrue(res[3].isSuccess());
    }
}
