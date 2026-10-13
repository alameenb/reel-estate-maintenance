@IsTest
private class MaintenanceAppointmentNotificationTest {
    @IsTest static void infoRequiredAndAppointmentSendOneEachClearingSendsNone() {
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', c.Id, false);
        cs[0].OwnerId = csr.Id;
        insert cs;
        System.runAs(csr) {
            MaintenanceMessaging.emailsQueued = 0;
            cs[0].Status = 'Awaiting Customer Information';
            update cs;
            Assert.areEqual(1, MaintenanceMessaging.emailsQueued, 'Information required: one email');
            cs[0].Appointment_DateTime__c = Datetime.now().addDays(2);
            update cs;
            Assert.areEqual(2, MaintenanceMessaging.emailsQueued, 'Appointment set');
            cs[0].Appointment_DateTime__c = Datetime.now().addDays(3);
            update cs;
            Assert.areEqual(3, MaintenanceMessaging.emailsQueued, 'Appointment changed');
            cs[0].Appointment_DateTime__c = null;
            update cs;
            Assert.areEqual(3, MaintenanceMessaging.emailsQueued, 'Cleared: nothing sent');
        }
    }

    @IsTest static void bulkAppointments() {
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', c.Id, true);
        MaintenanceMessaging.emailsQueued = 0;
        Test.startTest();
        for (Case x : cs) { x.Appointment_DateTime__c = Datetime.now().addDays(1); }
        update cs;
        Test.stopTest();
        Assert.areEqual(200, MaintenanceMessaging.emailsQueued);
    }
}
