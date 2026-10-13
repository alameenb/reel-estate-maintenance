/**
 * CMP-047. Guest intake for the public website form.
 *
 * DOCUMENTED EXCEPTION: runs WITHOUT SHARING because the site guest user has no
 * access to Contact, Property or Case. It is reachable only through
 * MaintenanceRequestIntakeController, validates every input server-side, and returns
 * only the new CaseNumber, never record data.
 */
public without sharing class MaintenanceRequestIntakeService {
    public class IntakeRequest {
        public String name; public String email; public String phone;
        public String street; public String city; public String postalCode;
        public String category; public String description; public Datetime preferredAppointment;
    }
    public class FileInput { public String fileName; public String base64Data; }

    public class IntakeValidationException extends Exception {
        public Map<String, String> fieldErrors = new Map<String, String>();
    }

    public static final Set<String> MANDATORY = new Set<String>{ 'name', 'email', 'street', 'postalCode', 'category', 'description' };
    private static final Pattern EMAIL = Pattern.compile('^[A-Za-z0-9._%+\'-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$');
    private static final Pattern PHONE = Pattern.compile('^[0-9 +()\\-]{6,20}$');

    public static Set<String> validCategories() {
        Set<String> s = new Set<String>();
        for (Schema.PicklistEntry e : Case.Issue_Category__c.getDescribe().getPicklistValues()) { if (e.isActive()) { s.add(e.getValue()); } }
        return s;
    }

    public static List<String> allowedExtensions() {
        String raw = MaintenanceConstants.settings().Allowed_File_Extensions__c;
        List<String> out = new List<String>();
        if (String.isNotBlank(raw)) { for (String x : raw.split(',')) { if (String.isNotBlank(x)) { out.add(x.trim().toLowerCase()); } } }
        return out;
    }

    public static void validate(IntakeRequest req, List<FileInput> files) {
        IntakeValidationException ex = new IntakeValidationException('Please correct the highlighted fields.');
        Map<String, String> values = new Map<String, String>{
            'name' => req?.name, 'email' => req?.email, 'street' => req?.street,
            'postalCode' => req?.postalCode, 'category' => req?.category, 'description' => req?.description };
        for (String f : MANDATORY) { if (String.isBlank(values.get(f))) { ex.fieldErrors.put(f, 'This field is required.'); } }
        if (req != null) {
            if (String.isNotBlank(req.email) && !EMAIL.matcher(req.email.trim()).matches()) { ex.fieldErrors.put('email', 'Enter a valid email address.'); }
            if (String.isNotBlank(req.phone) && !PHONE.matcher(req.phone.trim()).matches()) { ex.fieldErrors.put('phone', 'Enter a valid phone number.'); }
            if (String.isNotBlank(req.category) && !validCategories().contains(req.category)) { ex.fieldErrors.put('category', 'Choose a category from the list.'); }
            if (req.preferredAppointment != null && req.preferredAppointment < Datetime.now()) { ex.fieldErrors.put('preferredAppointment', 'Choose a time in the future.'); }
        }
        Request_Setting__mdt s = MaintenanceConstants.settings();
        List<FileInput> fs = files == null ? new List<FileInput>() : files;
        Integer maxCount = s.Max_File_Count__c == null ? 3 : s.Max_File_Count__c.intValue();
        Integer maxKb = s.Max_File_Size_KB__c == null ? 1024 : s.Max_File_Size_KB__c.intValue();
        List<String> exts = allowedExtensions();
        if (fs.size() > maxCount) { ex.fieldErrors.put('files', 'You can attach up to ' + maxCount + ' files.'); }
        for (FileInput f : fs) {
            String n = f.fileName == null ? '' : f.fileName.toLowerCase();
            String ext = n.contains('.') ? n.substringAfterLast('.') : '';
            if (!exts.isEmpty() && !exts.contains(ext)) { ex.fieldErrors.put('files', f.fileName + ': file type not allowed. Allowed: ' + String.join(exts, ', ') + '.'); }
            Integer bytes = f.base64Data == null ? 0 : (f.base64Data.length() * 3) / 4;
            if (bytes > maxKb * 1024) { ex.fieldErrors.put('files', f.fileName + ': larger than ' + maxKb + ' KB.'); }
        }
        if (!ex.fieldErrors.isEmpty()) { throw ex; }
    }

    public static String normalisePostcode(String p) { return p == null ? null : p.replaceAll('\\s', '').toUpperCase(); }

    public static String submit(IntakeRequest req, List<FileInput> files) {
        validate(req, files);
        Savepoint sp = Database.setSavepoint();
        try {
            Contact contact = matchOrCreateContact(req);
            Property__c property = matchOrCreateProperty(req);
            linkCustomer(property.Id, contact.Id);

            List<Group> q = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName = :MaintenanceConstants.INTAKE_QUEUE LIMIT 1];
            Case c = new Case(
                RecordTypeId = MaintenanceConstants.recordTypeId(), Status = MaintenanceConstants.STATUS_NEW, Origin = 'Web',
                Subject = (req.category.replace('_', ' ') + ' request - ' + req.street.trim()).left(255),
                Description = req.description.trim(), SuppliedName = req.name.trim().left(80), SuppliedEmail = req.email.trim(),
                SuppliedPhone = String.isBlank(req.phone) ? null : req.phone.trim(), ContactId = contact.Id, AccountId = contact.AccountId,
                Property__c = property.Id, Issue_Category__c = req.category, Preferred_Appointment__c = req.preferredAppointment);
            if (!q.isEmpty()) { c.OwnerId = q[0].Id; }
            insert c;

            if (files != null && !files.isEmpty()) {
                List<ContentVersion> cvs = new List<ContentVersion>();
                for (FileInput f : files) {
                    cvs.add(new ContentVersion(Title = f.fileName.substringBeforeLast('.'), PathOnClient = f.fileName,
                        VersionData = EncodingUtil.base64Decode(f.base64Data), FirstPublishLocationId = c.Id));
                }
                insert cvs;
            }
            return [SELECT CaseNumber FROM Case WHERE Id = :c.Id].CaseNumber;
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
    }

    private static Contact matchOrCreateContact(IntakeRequest req) {
        String email = req.email.trim().toLowerCase();
        List<Contact> found = [SELECT Id, AccountId FROM Contact WHERE Email = :email ORDER BY CreatedDate ASC LIMIT 1];
        if (!found.isEmpty()) { return found[0]; }
        String full = req.name.trim();
        String first = full.contains(' ') ? full.substringBeforeLast(' ') : null;
        String last = full.contains(' ') ? full.substringAfterLast(' ') : full;
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        Account a = new Account(Name = full.left(255));
        Database.insert(a, dml);
        Contact c = new Contact(AccountId = a.Id, FirstName = first == null ? null : first.left(40), LastName = last.left(80),
            Email = email, Phone = String.isBlank(req.phone) ? null : req.phone.trim());
        Database.insert(c, dml);
        return c;
    }

    private static Property__c matchOrCreateProperty(IntakeRequest req) {
        String pc = normalisePostcode(req.postalCode);
        String street = req.street.trim();
        for (Property__c p : [SELECT Id, Street__c, Postal_Code__c FROM Property__c WHERE Postal_Code__c = :pc LIMIT 200]) {
            if (p.Street__c != null && p.Street__c.trim().equalsIgnoreCase(street)) { return p; }
        }
        Property__c p = new Property__c(Name = street.left(80), Street__c = street, City__c = String.isBlank(req.city) ? null : req.city.trim(), Postal_Code__c = pc);
        insert p;
        return p;
    }

    private static void linkCustomer(Id propertyId, Id contactId) {
        if ([SELECT COUNT() FROM Property_Customer__c WHERE Property__c = :propertyId AND Contact__c = :contactId] == 0) {
            insert new Property_Customer__c(Property__c = propertyId, Contact__c = contactId);
        }
    }
}
