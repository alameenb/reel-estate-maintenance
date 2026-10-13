@IsTest
private class RequestAssignmentServiceTest {
    private static List<Request_Assignment__c> periods(Id caseId, String type) {
        return [SELECT Assignee_User__c, Team__c, Start__c, End__c, Duration_Hours__c FROM Request_Assignment__c WHERE Case__c = :caseId AND Assignment_Type__c = :type ORDER BY Start__c, Name];
    }

    @IsTest static void insertWithUserOwnerOpensRepresentativePeriod() {
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, false);
        cs[0].OwnerId = UserInfo.getUserId();
        insert cs;
        List<Request_Assignment__c> p = periods(cs[0].Id, 'Representative');
        Assert.areEqual(1, p.size());
        Assert.areEqual(UserInfo.getUserId(), p[0].Assignee_User__c);
        Assert.isNull(p[0].End__c);
        Assert.isNull(p[0].Duration_Hours__c, 'Open periods have no duration');
    }

    @IsTest static void queueOwnerOpensNoPeriod() {
        Group q = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = 'Maintenance_Requests'];
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, false);
        cs[0].OwnerId = q.Id;
        insert cs;
        Assert.areEqual(0, periods(cs[0].Id, 'Representative').size());
    }

    @IsTest static void reassignmentAndTeamChangeRollPeriods() {
        User other = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, true);
        cs[0].OwnerId = other.Id;
        cs[0].Maintenance_Team__c = 'Plumbing_Team';
        update cs;
        List<Request_Assignment__c> rep = periods(cs[0].Id, 'Representative');
        Assert.areEqual(2, rep.size());
        Assert.isNotNull(rep[0].End__c, 'First period closed on reassignment');
        Assert.areEqual(other.Id, rep[1].Assignee_User__c);
        Assert.areEqual('Plumbing_Team', periods(cs[0].Id, 'Team')[0].Team__c);
        cs[0].Maintenance_Team__c = 'Electrical_Team';
        update cs;
        List<Request_Assignment__c> team = periods(cs[0].Id, 'Team');
        Assert.areEqual(2, team.size());
        Assert.isNotNull(team[0].End__c);
    }

    @IsTest static void closingEndsAllOpenPeriodsAndDurationIsHours() {
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, false);
        cs[0].Maintenance_Team__c = 'Plumbing_Team';
        insert cs;
        cs[0].Status = 'Closed';
        update cs;
        Assert.areEqual(0, [SELECT COUNT() FROM Request_Assignment__c WHERE Case__c = :cs[0].Id AND End__c = NULL]);
        Request_Assignment__c p = new Request_Assignment__c(Start__c = Datetime.newInstance(2026, 1, 1, 0, 0, 0), End__c = Datetime.newInstance(2026, 1, 3, 0, 0, 0));
        Formula.recalculateFormulas(new List<Request_Assignment__c>{ p });
        Assert.areEqual(48.00, p.Duration_Hours__c);
    }

    @IsTest static void bulkReassignThenClose() {
        User other = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', null, false);
        for (Case c : cs) { c.OwnerId = UserInfo.getUserId(); }
        insert cs;
        Test.startTest();
        for (Case c : cs) { c.OwnerId = other.Id; }
        update cs;
        for (Case c : cs) { c.Status = 'Closed'; }
        update cs;
        Test.stopTest();
        Assert.areEqual(400, [SELECT COUNT() FROM Request_Assignment__c WHERE Case__c IN :cs]);
        Assert.areEqual(0, [SELECT COUNT() FROM Request_Assignment__c WHERE Case__c IN :cs AND End__c = NULL]);
    }

    @IsTest static void csrWithoutInsightsCannotReadPeriods() {
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        System.runAs(csr) {
            Assert.isFalse(Schema.SObjectType.Request_Assignment__c.isAccessible(), 'Periods are for managers (Maintenance_Manager_Insights)');
        }
        User mgr = TestDataFactory.createUserWithPermissionSet('Maintenance_Manager_Insights', null);
        System.runAs(mgr) { Assert.isTrue(Schema.SObjectType.Request_Assignment__c.isAccessible()); }
    }
}
