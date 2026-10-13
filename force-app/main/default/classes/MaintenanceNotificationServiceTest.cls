@IsTest
private class MaintenanceNotificationServiceTest {
    private static Notification_Rule__mdt rule(String ev, String status, String tpl, Boolean active) {
        return new Notification_Rule__mdt(DeveloperName = 'T_' + ev + status, Event__c = ev, Status__c = status, Email_Template__c = tpl,
            Notification_Type__c = 'Maintenance_Request_Message', Notification_Title__c = 'T', Active__c = active);
    }
    private static MaintenanceNotificationService.Request r(Id caseId, String ev) {
        MaintenanceNotificationService.Request x = new MaintenanceNotificationService.Request(); x.caseId = caseId; x.eventName = ev; return x;
    }

    @IsTest static void matchingRuleSendsEmailInactiveDoesNot() {
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', c.Id, true);
        MaintenanceNotificationService.rulesOverride = new List<Notification_Rule__mdt>{ rule('Submitted', null, 'Maintenance_Request_Acknowledgement', true) };
        MaintenanceMessaging.emailsQueued = 0;
        MaintenanceNotificationService.sendNotifications(new List<MaintenanceNotificationService.Request>{ r(cs[0].Id, 'Submitted') });
        Assert.areEqual(1, MaintenanceMessaging.emailsQueued);
        MaintenanceNotificationService.rulesOverride = new List<Notification_Rule__mdt>{ rule('Submitted', null, 'Maintenance_Request_Acknowledgement', false) };
        MaintenanceNotificationService.sendNotifications(new List<MaintenanceNotificationService.Request>{ r(cs[0].Id, 'Submitted') });
        Assert.areEqual(1, MaintenanceMessaging.emailsQueued, 'Inactive rule sends nothing');
    }

    @IsTest static void specificStatusRuleWinsOverGeneric() {
        List<Notification_Rule__mdt> rules = new List<Notification_Rule__mdt>{
            rule('Status_Changed', null, 'Maintenance_Request_Status_Changed', true),
            rule('Status_Changed', 'Resolved', 'Maintenance_Request_Resolved', true) };
        Assert.areEqual('Maintenance_Request_Resolved', MaintenanceNotificationService.matching(rules, 'Status_Changed', 'Resolved')[0].Email_Template__c);
        Assert.areEqual(1, MaintenanceNotificationService.matching(rules, 'Status_Changed', 'Resolved').size());
        Assert.areEqual('Maintenance_Request_Status_Changed', MaintenanceNotificationService.matching(rules, 'Status_Changed', 'In Progress')[0].Email_Template__c);
    }

    @IsTest static void missingTemplateIsSkipped() {
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', c.Id, true);
        MaintenanceNotificationService.rulesOverride = new List<Notification_Rule__mdt>{ rule('Submitted', null, 'Does_Not_Exist', true) };
        MaintenanceMessaging.emailsQueued = 0;
        MaintenanceNotificationService.sendNotifications(new List<MaintenanceNotificationService.Request>{ r(cs[0].Id, 'Submitted') });
        Assert.areEqual(0, MaintenanceMessaging.emailsQueued);
    }

    @IsTest static void bulkTwoHundredAsCsr() {
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', c.Id, false);
        for (Case x : cs) { x.OwnerId = csr.Id; }
        insert cs;
        List<MaintenanceNotificationService.Request> reqs = new List<MaintenanceNotificationService.Request>();
        for (Case x : cs) { reqs.add(r(x.Id, 'Status_Changed')); }
        MaintenanceMessaging.emailsQueued = 0;
        System.runAs(csr) {
            Test.startTest();
            MaintenanceNotificationService.sendNotifications(reqs);
            Test.stopTest();
        }
        Assert.areEqual(200, MaintenanceMessaging.emailsQueued);
    }
}
