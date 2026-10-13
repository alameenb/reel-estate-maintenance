/**
 * Email and custom-notification helper shared by the notification service, the
 * feed trigger and the flows. Sending never throws: failures are logged so a
 * customer message can never block a record save. Test-visible counters let
 * tests assert what would have been sent even when org email deliverability is off.
 */
public with sharing class MaintenanceMessaging {
    @TestVisible public static Integer emailsQueued = 0;
    @TestVisible public static Integer notificationsQueued = 0;
    @TestVisible public static List<String> log = new List<String>();

    private static Map<String, Id> templateIds = new Map<String, Id>();
    private static Map<String, Id> notificationTypeIds = new Map<String, Id>();
    private static Id orgWideIdCache;
    private static Boolean orgWideResolved = false;

    private static Map<String, EmailTemplate> templates = new Map<String, EmailTemplate>();

    /** Templates are read once per transaction; merging is done in memory so bulk sends use no extra queries. */
    public static EmailTemplate template(String developerName) {
        if (String.isBlank(developerName)) { return null; }
        if (!templates.containsKey(developerName)) {
            List<EmailTemplate> t = [SELECT Id, Subject, HtmlValue, Body FROM EmailTemplate WHERE DeveloperName = :developerName LIMIT 1];
            templates.put(developerName, t.isEmpty() ? null : t[0]);
        }
        return templates.get(developerName);
    }

    public static final String CASE_FIELDS = 'Id, CaseNumber, Subject, Status, Issue_Category__c, Portal_Link__c, Appointment_DateTime__c, ContactId, Contact.FirstName, Contact.Email';

    public static Id templateId(String developerName) { EmailTemplate t = template(developerName); return t == null ? null : t.Id; }

    public static Id notificationTypeId(String developerName) {
        if (String.isBlank(developerName)) { return null; }
        if (!notificationTypeIds.containsKey(developerName)) {
            List<CustomNotificationType> t = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = :developerName LIMIT 1];
            notificationTypeIds.put(developerName, t.isEmpty() ? null : t[0].Id);
        }
        return notificationTypeIds.get(developerName);
    }

    public static Id orgWideEmailId(String address) {
        String a = String.isNotBlank(address) ? address : MaintenanceConstants.settings().Org_Wide_Email_Address__c;
        if (String.isBlank(a)) { return null; }
        if (!orgWideResolved) {
            List<OrgWideEmailAddress> o = [SELECT Id FROM OrgWideEmailAddress WHERE Address = :a LIMIT 1];
            orgWideIdCache = o.isEmpty() ? null : o[0].Id;
            orgWideResolved = true;
        }
        return orgWideIdCache;
    }

    /** Build an email from a stored template for the case's contact, replacing [[MESSAGE_BODY]] when given. */
    public static Messaging.SingleEmailMessage buildEmail(String templateDeveloperName, Case c, String messageBody, String senderAddress) {
        EmailTemplate t = template(templateDeveloperName);
        if (t == null || c == null || c.ContactId == null) {
            log.add('Skipped email: template ' + templateDeveloperName + ' or contact missing for ' + (c == null ? null : c.Id));
            return null;
        }
        String safe = messageBody == null ? '' : messageBody.escapeHtml4().replace('\n', '<br/>');
        Messaging.SingleEmailMessage m = new Messaging.SingleEmailMessage();
        m.setSubject(mergeFields(t.Subject, c, false));
        if (t.HtmlValue != null) { m.setHtmlBody(mergeFields(t.HtmlValue, c, true).replace('[[MESSAGE_BODY]]', safe)); }
        m.setPlainTextBody(mergeFields(t.Body == null ? '' : t.Body, c, false).replace('[[MESSAGE_BODY]]', messageBody == null ? '' : messageBody));
        m.setTargetObjectId(c.ContactId);
        m.setWhatId(c.Id);
        m.setSaveAsActivity(true);
        Id ow = orgWideEmailId(senderAddress);
        if (ow != null) { m.setOrgWideEmailAddressId(ow); }
        return m;
    }

    @TestVisible
    private static String mergeFields(String text, Case c, Boolean html) {
        if (text == null) { return null; }
        Map<String, String> v = new Map<String, String>{
            '{!Case.CaseNumber}' => c.CaseNumber, '{!Case.Subject}' => c.Subject, '{!Case.Status}' => c.Status,
            '{!Case.Issue_Category__c}' => c.Issue_Category__c == null ? '' : c.Issue_Category__c.replace('_', ' '),
            '{!Case.Portal_Link__c}' => c.Portal_Link__c,
            '{!Case.Appointment_DateTime__c}' => c.Appointment_DateTime__c == null ? '' : c.Appointment_DateTime__c.format('EEE d MMM yyyy h:mm a'),
            '{!Contact.FirstName}' => c.Contact == null || c.Contact.FirstName == null ? 'there' : c.Contact.FirstName };
        String out = text;
        for (String k : v.keySet()) {
            String val = v.get(k) == null ? '' : v.get(k);
            out = out.replace(k, html ? val.escapeHtml4() : val);
        }
        return out;
    }

    public static void send(List<Messaging.SingleEmailMessage> emails) {
        List<Messaging.SingleEmailMessage> toSend = new List<Messaging.SingleEmailMessage>();
        for (Messaging.SingleEmailMessage m : emails) { if (m != null) { toSend.add(m); } }
        if (toSend.isEmpty()) { return; }
        emailsQueued += toSend.size();
        try {
            Messaging.sendEmail(toSend, false);
        } catch (Exception e) {
            log.add('Email send failed (check Setup > Deliverability): ' + e.getMessage());
        }
    }

    public static void notify(String typeDeveloperName, String title, String body, Id targetId, Set<String> recipientIds) {
        Id typeId = notificationTypeId(typeDeveloperName);
        if (typeId == null || recipientIds == null || recipientIds.isEmpty()) {
            log.add('Skipped notification for ' + targetId);
            return;
        }
        notificationsQueued++;
        try {
            Messaging.CustomNotification n = new Messaging.CustomNotification();
            n.setNotificationTypeId(typeId);
            n.setTitle(title.left(250));
            n.setBody(String.isBlank(body) ? title : body.left(750));
            n.setTargetId(targetId);
            n.send(recipientIds);
        } catch (Exception e) {
            log.add('Notification failed for ' + targetId + ': ' + e.getMessage());
        }
    }

    /**
     * Cases with the customer fields needed for messaging. DOCUMENTED EXCEPTION: read in
     * system mode, because the sender (a CSR, or automation) may not see the customer's
     * Contact record but must still be able to notify them. No data is returned to the UI.
     */
    public static Map<Id, Case> casesForMessaging(Set<Id> caseIds) { return casesStatic(caseIds); }

    private without sharing class SystemReads {
        Map<Id, Case> casesImpl(Set<Id> ids) {
            return new Map<Id, Case>((List<Case>) Database.query('SELECT OwnerId, RecordTypeId, ' + CASE_FIELDS + ' FROM Case WHERE Id IN :ids'));
        }
    }
    private static Map<Id, Case> casesStatic(Set<Id> ids) { return new SystemReads().casesImpl(ids); }

    /** Active portal users keyed by ContactId (system read of User; documented exception). */
    public static Map<Id, Id> portalUsersByContact(Set<Id> contactIds) {
        Map<Id, Id> result = new Map<Id, Id>();
        if (contactIds == null || contactIds.isEmpty()) { return result; }
        for (User u : [SELECT Id, ContactId FROM User WHERE ContactId IN :contactIds AND IsActive = TRUE]) {
            result.put(u.ContactId, u.Id);
        }
        return result;
    }
}
