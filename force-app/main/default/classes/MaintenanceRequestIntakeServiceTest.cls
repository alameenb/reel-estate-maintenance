@IsTest
private class MaintenanceRequestIntakeServiceTest {
    private static MaintenanceRequestIntakeService.IntakeRequest req(String email, String street) {
        MaintenanceRequestIntakeService.IntakeRequest r = new MaintenanceRequestIntakeService.IntakeRequest();
        r.name = 'Priya Sharma'; r.email = email; r.phone = '0400 123 456'; r.street = street; r.city = 'Officer';
        r.postalCode = '3809'; r.category = 'Plumbing'; r.description = 'Kitchen tap leaking';
        r.preferredAppointment = Datetime.now().addDays(3);
        return r;
    }
    private static MaintenanceRequestIntakeService.FileInput file(String name, Integer bytes) {
        MaintenanceRequestIntakeService.FileInput f = new MaintenanceRequestIntakeService.FileInput();
        f.fileName = name; f.base64Data = EncodingUtil.base64Encode(Blob.valueOf('x'.repeat(bytes)));
        return f;
    }

    @IsTest static void happyPathStoresEverything() {
        String ref = MaintenanceRequestIntakeService.submit(req('priya@example.com', '12 Station St'),
            new List<MaintenanceRequestIntakeService.FileInput>{ file('leak.jpg', 100) });
        Case c = [SELECT Id, ContactId, Property__c, Issue_Category__c, Preferred_Appointment__c, SuppliedEmail, Owner.Name, RecordType.DeveloperName FROM Case WHERE CaseNumber = :ref];
        Assert.areEqual('Maintenance_Request', c.RecordType.DeveloperName);
        Assert.areEqual('Plumbing', c.Issue_Category__c);
        Assert.isNotNull(c.Preferred_Appointment__c);
        Assert.areEqual('priya@example.com', c.SuppliedEmail);
        Assert.areEqual('3809', [SELECT Postal_Code__c FROM Property__c WHERE Id = :c.Property__c].Postal_Code__c);
        Assert.areEqual(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id]);
        Assert.areEqual(1, [SELECT COUNT() FROM Property_Customer__c WHERE Contact__c = :c.ContactId AND Property__c = :c.Property__c AND Relationship__c = NULL]);
    }

    @IsTest static void reusesContactPropertyAndJunction() {
        MaintenanceRequestIntakeService.submit(req('repeat@example.com', '1 Main Rd'), null);
        MaintenanceRequestIntakeService.submit(req('REPEAT@example.com', '1 main rd'), null);
        MaintenanceRequestIntakeService.submit(req('repeat@example.com', '9 Other St'), null);
        Assert.areEqual(1, [SELECT COUNT() FROM Contact WHERE Email = 'repeat@example.com']);
        Assert.areEqual(2, [SELECT COUNT() FROM Property__c]);
        Assert.areEqual(2, [SELECT COUNT() FROM Property_Customer__c], 'One link per property, no duplicates');
        Assert.areEqual(3, [SELECT COUNT() FROM Case WHERE Contact.Email = 'repeat@example.com']);
    }

    @IsTest static void rejectsMissingAndInvalidFields() {
        MaintenanceRequestIntakeService.IntakeRequest r = new MaintenanceRequestIntakeService.IntakeRequest();
        r.email = 'not-an-email'; r.category = 'Nonsense'; r.phone = 'abc';
        try {
            MaintenanceRequestIntakeService.submit(r, null);
            Assert.fail('Expected validation error');
        } catch (MaintenanceRequestIntakeService.IntakeValidationException e) {
            for (String f : new List<String>{ 'name', 'street', 'postalCode', 'description', 'email', 'category', 'phone' }) {
                Assert.isTrue(e.fieldErrors.containsKey(f), 'Missing error for ' + f);
            }
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Case]);
    }

    @IsTest static void rejectsBadFiles() {
        List<String> expected = new List<String>();
        try { MaintenanceRequestIntakeService.submit(req('a@example.com', '1 A St'), new List<MaintenanceRequestIntakeService.FileInput>{ file('virus.exe', 10) }); Assert.fail(); }
        catch (MaintenanceRequestIntakeService.IntakeValidationException e) { Assert.isTrue(e.fieldErrors.get('files').contains('not allowed')); }
        try { MaintenanceRequestIntakeService.submit(req('a@example.com', '1 A St'), new List<MaintenanceRequestIntakeService.FileInput>{ file('big.pdf', 2 * 1024 * 1024) }); Assert.fail(); }
        catch (MaintenanceRequestIntakeService.IntakeValidationException e) { Assert.isTrue(e.fieldErrors.get('files').contains('larger')); }
        List<MaintenanceRequestIntakeService.FileInput> many = new List<MaintenanceRequestIntakeService.FileInput>();
        for (Integer i = 0; i < 5; i++) { many.add(file('p' + i + '.png', 10)); }
        try { MaintenanceRequestIntakeService.submit(req('a@example.com', '1 A St'), many); Assert.fail(); }
        catch (MaintenanceRequestIntakeService.IntakeValidationException e) { Assert.isTrue(e.fieldErrors.get('files').contains('up to')); }
        Assert.areEqual(0, [SELECT COUNT() FROM Contact]);
    }

    @IsTest static void rollsBackOnFailure() {
        MaintenanceRequestIntakeService.FileInput broken = new MaintenanceRequestIntakeService.FileInput();
        broken.fileName = 'x.jpg'; broken.base64Data = null; // VersionData null -> insert fails after Case insert
        try { MaintenanceRequestIntakeService.submit(req('rb@example.com', '5 Roll St'), new List<MaintenanceRequestIntakeService.FileInput>{ broken }); Assert.fail(); }
        catch (Exception e) { }
        Assert.areEqual(0, [SELECT COUNT() FROM Case]);
        Assert.areEqual(0, [SELECT COUNT() FROM Contact WHERE Email = 'rb@example.com']);
    }

    @IsTest static void manySequentialSubmissions() {
        Test.startTest();
        for (Integer i = 0; i < 8; i++) { MaintenanceRequestIntakeService.submit(req('bulk' + i + '@example.com', i + ' Bulk St'), null); }
        Test.stopTest();
        Assert.areEqual(8, [SELECT COUNT() FROM Case]);
    }

    @IsTest static void propertyUserCanReadButNotDeleteProperties() {
        MaintenanceRequestIntakeService.submit(req('pu@example.com', '3 Prop St'), null);
        User u = TestDataFactory.createInternalUser(new List<String>{ 'Maintenance_CSR', 'Maintenance_Property_User' }, null, null);
        System.runAs(u) {
            Assert.isTrue(Schema.SObjectType.Property__c.isAccessible());
            Assert.isFalse(Schema.SObjectType.Property__c.isDeletable());
            Assert.areEqual(1, [SELECT COUNT() FROM Property__c WITH USER_MODE]);
        }
    }
}
