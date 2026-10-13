/**
 * CMP-076. Manager permissions and the overdue flag. Visibility of every request to managers comes
 * from the criteria-based sharing rule (CMP-067); this org calculates rule shares asynchronously, so
 * that part is verified against real records by scripts/apex/verify-sharing.apex.
 */
@IsTest
private class MaintenanceManagerAccessTest {
    @IsTest static void managerIsReadOnlyAndRestrictedUserSeesNothing() {
        User mgr = TestDataFactory.createInternalUser(new List<String>{ 'Maintenance_Supervisor_Manager', 'Maintenance_Manager_Insights' }, null, null);
        User nobody = TestDataFactory.createInternalUser(new List<String>(), null, null);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', null, true);
        System.runAs(mgr) {
            Assert.isTrue(Schema.SObjectType.Case.isAccessible());
            Assert.isFalse(Schema.SObjectType.Case.isUpdateable(), 'Managers have read-only object access');
            Assert.isFalse(Schema.SObjectType.Case.isCreateable());
            Assert.isTrue(Schema.SObjectType.Case.fields.Is_Overdue__c.isAccessible());
            Assert.isTrue(Schema.SObjectType.Request_Assignment__c.isAccessible());
        }
        System.runAs(nobody) {
            Assert.areEqual(0, [SELECT COUNT() FROM Case WHERE Id IN :cs]);
        }
    }

    @IsTest static void overdueOnlyForPastDueUnresolved() {
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', null, true);
        for (Integer i = 0; i < cs.size(); i++) {
            cs[i].Escalation_Due__c = i < 100 ? Datetime.now().addHours(-1) : Datetime.now().addDays(1);
            if (i < 20) { cs[i].Status = 'Resolved'; } else if (i < 40) { cs[i].Status = 'Closed'; }
        }
        update cs;
        Assert.areEqual(60, [SELECT COUNT() FROM Case WHERE Id IN :cs AND Is_Overdue__c = TRUE]);
    }
}
