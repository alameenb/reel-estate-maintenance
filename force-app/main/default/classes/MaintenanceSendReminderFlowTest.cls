@IsTest
private class MaintenanceSendReminderFlowTest {
    private static Map<String, Object> run(Id caseId) {
        Flow.Interview.Maintenance_Send_Reminder_Action fi = new Flow.Interview.Maintenance_Send_Reminder_Action(
            new Map<String, Object>{ 'recordId' => caseId, 'reminderNote' => 'Please upload a photo of the meter' });
        fi.start();
        return new Map<String, Object>{ 'sent' => fi.getVariableValue('notificationSent'), 'error' => fi.getVariableValue('errorMessage') };
    }

    @IsTest static void sendsEmailAndLogsTask() {
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', c.Id, true);
        MaintenanceMessaging.emailsQueued = 0;
        Test.startTest();
        Map<String, Object> out = run(cs[0].Id);
        Test.stopTest();
        Assert.areEqual(false, out.get('sent'), 'No portal user, so email only');
        Assert.areEqual(1, MaintenanceMessaging.emailsQueued);
        Task t = [SELECT Subject, WhoId, Status, Description FROM Task WHERE WhatId = :cs[0].Id AND Subject = 'Reminder sent: outstanding information'];
        Assert.areEqual(c.Id, t.WhoId);
        Assert.areEqual('Completed', t.Status);
    }

    @IsTest static void portalCustomerAlsoGetsNotification() {
        Map<String, SObject> pc = TestDataFactory.createPortalCustomer(new List<String>{ 'Maintenance_Portal_Customer' });
        if (pc == null) { Assert.isNull(TestDataFactory.portalProfile(), 'No community licence in this org'); return; }
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', pc.get('contact').Id, true);
        Assert.areEqual(true, run(cs[0].Id).get('sent'));
    }

    @IsTest static void contactWithoutEmailReturnsError() {
        Contact c = TestDataFactory.createAccountWithContact(false);
        c.Email = null;
        insert c;
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', c.Id, true);
        Map<String, Object> out = run(cs[0].Id);
        Assert.isNotNull(out.get('error'));
        Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE WhatId = :cs[0].Id]);
    }
}
