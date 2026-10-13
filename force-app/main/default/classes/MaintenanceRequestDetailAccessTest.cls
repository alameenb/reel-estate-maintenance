@IsTest
private class MaintenanceRequestDetailAccessTest {
    @IsTest static void owningCsrReadsDetailsAndFiles() {
        MaintenanceRequestIntakeService.IntakeRequest r = new MaintenanceRequestIntakeService.IntakeRequest();
        r.name = 'Jo Bloggs'; r.email = 'jo@example.com'; r.phone = '0411 111 111'; r.street = '4 Hill St'; r.postalCode = '3810';
        r.category = 'Appliances'; r.description = 'Oven not heating'; r.preferredAppointment = Datetime.now().addDays(2);
        List<MaintenanceRequestIntakeService.FileInput> fs = new List<MaintenanceRequestIntakeService.FileInput>();
        for (String n : new List<String>{ 'oven.jpg', 'manual.pdf' }) {
            MaintenanceRequestIntakeService.FileInput f = new MaintenanceRequestIntakeService.FileInput();
            f.fileName = n; f.base64Data = EncodingUtil.base64Encode(Blob.valueOf('data')); fs.add(f);
        }
        String ref = MaintenanceRequestIntakeService.submit(r, fs);
        User csr = TestDataFactory.createInternalUser(new List<String>{ 'Maintenance_CSR', 'Maintenance_Property_User' }, null, null);
        User other = TestDataFactory.createUserWithPermissionSet('Maintenance_CSR', null);
        Case c = [SELECT Id FROM Case WHERE CaseNumber = :ref];
        c.OwnerId = csr.Id;
        update c;
        System.runAs(csr) {
            Case seen = [SELECT SuppliedName, SuppliedEmail, SuppliedPhone, Property__c, Issue_Category__c, Description, Preferred_Appointment__c FROM Case WHERE Id = :c.Id WITH USER_MODE];
            Assert.areEqual('Jo Bloggs', seen.SuppliedName);
            Assert.isNotNull(seen.Property__c);
            Assert.isNotNull(seen.Preferred_Appointment__c);
            Assert.areEqual(2, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id]);
        }
        System.runAs(other) {
            Assert.areEqual(0, [SELECT COUNT() FROM Case WHERE Id = :c.Id WITH USER_MODE], 'Non-owner CSR cannot read it');
        }
    }
}
