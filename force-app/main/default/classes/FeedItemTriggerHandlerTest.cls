@IsTest
private class FeedItemTriggerHandlerTest {
    private static Case ownedCase(User csr, Contact c) {
        List<Case> cs = TestDataFactory.createMaintenanceCases(1, 'Plumbing', c.Id, false);
        cs[0].OwnerId = csr.Id;
        insert cs;
        return cs[0];
    }

    @IsTest static void ownerExternalPostEmailsCustomer() {
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        Contact c = TestDataFactory.createAccountWithContact(true);
        Case cs = ownedCase(csr, c);
        MaintenanceMessaging.emailsQueued = 0;
        System.runAs(csr) {
            Test.startTest();
            insert new FeedItem(ParentId = cs.Id, Body = 'We will visit on Monday', Visibility = 'AllUsers', Type = 'TextPost');
            Test.stopTest();
        }
        Assert.areEqual(1, MaintenanceMessaging.emailsQueued, String.join(MaintenanceMessaging.log, '; '));
    }

    @IsTest static void internalNonOwnerAndNoContactSendNothing() {
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        Contact c = TestDataFactory.createAccountWithContact(true);
        Case withContact = ownedCase(csr, c);
        List<Case> noContact = TestDataFactory.createMaintenanceCases(1, 'Plumbing', null, false);
        noContact[0].OwnerId = csr.Id;
        insert noContact;
        MaintenanceMessaging.emailsQueued = 0;
        System.runAs(csr) {
            insert new List<FeedItem>{
                new FeedItem(ParentId = withContact.Id, Body = 'internal note', Visibility = 'InternalUsers', Type = 'TextPost'),
                new FeedItem(ParentId = noContact[0].Id, Body = 'no contact', Visibility = 'AllUsers', Type = 'TextPost') };
        }
        // admin (not the owner) posts externally
        insert new FeedItem(ParentId = withContact.Id, Body = 'by someone else', Visibility = 'AllUsers', Type = 'TextPost');
        Assert.areEqual(0, MaintenanceMessaging.emailsQueued);
    }

    @IsTest static void bulkPostsUseOneSend() {
        User csr = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        Contact c = TestDataFactory.createAccountWithContact(true);
        List<Case> cs = TestDataFactory.createMaintenanceCases(200, 'Plumbing', c.Id, false);
        for (Case x : cs) { x.OwnerId = csr.Id; }
        insert cs;
        MaintenanceMessaging.emailsQueued = 0;
        List<FeedItem> posts = new List<FeedItem>();
        for (Case x : cs) { posts.add(new FeedItem(ParentId = x.Id, Body = 'Update', Visibility = 'AllUsers', Type = 'TextPost')); }
        System.runAs(csr) {
            Test.startTest();
            insert posts;
            Integer q = Limits.getQueries();
            Test.stopTest();
            Assert.isTrue(q < 20, 'Bulk-safe: ' + q + ' queries');
        }
        Assert.areEqual(200, MaintenanceMessaging.emailsQueued);
    }
}
