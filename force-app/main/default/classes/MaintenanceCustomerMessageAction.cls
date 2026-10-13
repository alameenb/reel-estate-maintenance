/**
 * Invocable used by the reminder flow (CMP-059): sends a template email and a portal
 * notification to the case's customer. Replaces the flow's Send Email + Send Custom
 * Notification elements so the same bulk-safe, failure-tolerant path is used everywhere.
 */
public with sharing class MaintenanceCustomerMessageAction {
    public class Input {
        @InvocableVariable(required=true) public Id caseId;
        @InvocableVariable(required=true) public String templateName;
        @InvocableVariable public String note;
        @InvocableVariable public String notificationTitle;
    }
    public class Output {
        @InvocableVariable public Boolean emailSent;
        @InvocableVariable public Boolean notificationSent;
        @InvocableVariable public String errorMessage;
    }

    @InvocableMethod(label='Message Maintenance Customer' description='Emails the case contact from a template and notifies their portal user.')
    public static List<Output> send(List<Input> inputs) {
        Set<Id> ids = new Set<Id>();
        for (Input i : inputs) { ids.add(i.caseId); }
        Map<Id, Case> cases = MaintenanceMessaging.casesForMessaging(ids);
        Set<Id> contactIds = new Set<Id>();
        for (Case c : cases.values()) { if (c.ContactId != null) { contactIds.add(c.ContactId); } }
        Map<Id, Id> portal = MaintenanceMessaging.portalUsersByContact(contactIds);
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Output> outs = new List<Output>();
        for (Input i : inputs) {
            Output o = new Output(); o.emailSent = false; o.notificationSent = false;
            Case c = cases.get(i.caseId);
            if (c == null || c.ContactId == null || String.isBlank(c.Contact.Email)) {
                o.errorMessage = 'This request has no customer email address.';
            } else {
                Messaging.SingleEmailMessage m = MaintenanceMessaging.buildEmail(i.templateName, c, i.note, null);
                if (m != null) { emails.add(m); o.emailSent = true; }
                if (portal.containsKey(c.ContactId)) {
                    MaintenanceMessaging.notify(MaintenanceConstants.NOTIFICATION_TYPE,
                        (String.isBlank(i.notificationTitle) ? 'Update on request' : i.notificationTitle) + ' ' + c.CaseNumber,
                        String.isBlank(i.note) ? c.Subject : i.note, c.Id, new Set<String>{ portal.get(c.ContactId) });
                    o.notificationSent = true;
                }
            }
            outs.add(o);
        }
        MaintenanceMessaging.send(emails);
        return outs;
    }
}
