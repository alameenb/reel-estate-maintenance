@IsTest
private class MaintenanceSatisfactionRatingTest {
    private static List<Case> resolvedCases(Integer n, Id contactId) {
        List<Case> cs = TestDataFactory.createMaintenanceCases(n, 'Plumbing', contactId, true);
        for (Case c : cs) { c.Status = 'Resolved'; }
        update cs;
        return cs;
    }

    @IsTest static void satisfactoryRatingStampsDate() {
        List<Case> cs = resolvedCases(1, TestDataFactory.createAccountWithContact(true).Id);
        cs[0].Satisfaction_Rating__c = 4;
        update cs;
        Case c = [SELECT Status, Satisfaction_Response_Date__c, Resolution_Outcome__c FROM Case WHERE Id = :cs[0].Id];
        Assert.isNotNull(c.Satisfaction_Response_Date__c);
        Assert.areEqual('Satisfactory - Resolved', c.Resolution_Outcome__c);
        Assert.areEqual('Resolved', c.Status, 'Stays Resolved until the 6-week auto-close');
        Assert.areEqual(0, [SELECT COUNT() FROM Case WHERE ParentId = :cs[0].Id]);
    }

    @IsTest static void lowRatingClosesAndCreatesLinkedChild() {
        Contact ct = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = resolvedCases(1, ct.Id);
        cs[0].Satisfaction_Rating__c = 1;
        update cs;
        Case parent = [SELECT Status, Resolution_Outcome__c, CaseNumber FROM Case WHERE Id = :cs[0].Id];
        Assert.areEqual('Closed', parent.Status);
        Assert.areEqual('Unresolved', parent.Resolution_Outcome__c);
        Case child = [SELECT Status, ContactId, Issue_Category__c, Subject, RecordType.DeveloperName FROM Case WHERE ParentId = :cs[0].Id];
        Assert.areEqual('New', child.Status);
        Assert.areEqual(ct.Id, child.ContactId);
        Assert.areEqual('Maintenance_Request', child.RecordType.DeveloperName);
        Assert.isTrue(child.Subject.startsWith('Follow-up: '));
        Assert.areEqual(1, [SELECT COUNT() FROM FeedItem WHERE ParentId = :cs[0].Id AND Visibility = 'InternalUsers']);
    }

    @IsTest static void ratingOnUnresolvedCaseCreatesNoChild() {
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', TestDataFactory.createAccountWithContact(true).Id, true);
        cs[0].Satisfaction_Rating__c = 1;
        update cs;
        Assert.areEqual(0, [SELECT COUNT() FROM Case WHERE ParentId = :cs[0].Id]);
    }

    @IsTest static void portalCustomerRatesOwnCaseOnly() {
        Map<String, SObject> a = TestDataFactory.createPortalCustomer(new List<String>{ 'Maintenance_Portal_Customer', 'Maintenance_Portal_Rating' });
        if (a == null) { Assert.isNull(TestDataFactory.portalProfile(), 'No community licence'); return; }
        Map<String, SObject> b = TestDataFactory.createPortalCustomer(new List<String>{ 'Maintenance_Portal_Customer', 'Maintenance_Portal_Rating' });
        List<Case> mine = resolvedCases(1, a.get('contact').Id);
        List<Case> theirs = resolvedCases(1, b.get('contact').Id);
        System.runAs((User) a.get('user')) {
            Database.update(new Case(Id = mine[0].Id, Satisfaction_Rating__c = 5), AccessLevel.USER_MODE);
            try { Database.update(new Case(Id = theirs[0].Id, Satisfaction_Rating__c = 5), AccessLevel.USER_MODE); Assert.fail(); } catch (Exception e) { }
        }
        Assert.areEqual(5, [SELECT Satisfaction_Rating__c FROM Case WHERE Id = :mine[0].Id].Satisfaction_Rating__c);
    }

    @IsTest static void bulkMixedRatings() {
        List<Case> cs = resolvedCases(200, TestDataFactory.createAccountWithContact(true).Id);
        Test.startTest();
        for (Integer i = 0; i < cs.size(); i++) { cs[i].Satisfaction_Rating__c = Math.mod(i, 2) == 0 ? 2 : 4; }
        update cs;
        Test.stopTest();
        Assert.areEqual(100, [SELECT COUNT() FROM Case WHERE ParentId IN :cs]);
        Assert.areEqual(100, [SELECT COUNT() FROM Case WHERE Id IN :cs AND Status = 'Closed']);
    }
}
