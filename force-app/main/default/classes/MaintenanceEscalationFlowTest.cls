@IsTest
private class MaintenanceEscalationFlowTest {
    @IsTest static void beforeSaveStampsEscalationDue() {
        Decimal days = MaintenanceConstants.settings().Escalation_Days__c;
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        System.runAs(csr) {
            Datetime before = Datetime.now();
            List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', null, true);
            for (Case c : [SELECT Escalation_Due__c FROM Case WHERE Id IN :cs]) {
                Assert.isNotNull(c.Escalation_Due__c);
                Long diffMinutes = (c.Escalation_Due__c.getTime() - before.addDays(days.intValue()).getTime()) / 60000;
                Assert.isTrue(Math.abs(diffMinutes) <= 5, 'Due date should be now + ' + days + ' days');
            }
        }
    }

    @IsTest static void overdueFormula() {
        List<Case> cs = new List<Case>{
            new Case(Status = 'New', Escalation_Due__c = Datetime.now().addHours(-1)),
            new Case(Status = 'Resolved', Escalation_Due__c = Datetime.now().addHours(-1)),
            new Case(Status = 'Closed', Escalation_Due__c = Datetime.now().addHours(-1)),
            new Case(Status = 'In Progress', Escalation_Due__c = Datetime.now().addDays(1)) };
        Formula.recalculateFormulas(cs);
        Assert.isTrue(cs[0].Is_Overdue__c);
        Assert.isFalse(cs[1].Is_Overdue__c);
        Assert.isFalse(cs[2].Is_Overdue__c);
        Assert.isFalse(cs[3].Is_Overdue__c);
    }
}
