/**
 * CMP-028. Customer-visible posts on a Maintenance Request:
 *  - the case owner (CSR) posts AllUsers  -> email (template + message) and portal notification to the customer
 *  - the portal customer posts            -> notification to the case owner
 * Internal-only posts never reach the customer.
 */
public with sharing class FeedItemTriggerHandler {
    public void afterInsert(List<FeedItem> items) {
        Map<Id, List<FeedItem>> byCase = new Map<Id, List<FeedItem>>();
        Set<Id> posters = new Set<Id>();
        for (FeedItem f : items) {
            if (f.ParentId == null || f.ParentId.getSObjectType() != Case.SObjectType) { continue; }
            if (f.Visibility != 'AllUsers' || (f.Type != 'TextPost' && f.Type != 'ContentPost')) { continue; }
            if (!byCase.containsKey(f.ParentId)) { byCase.put(f.ParentId, new List<FeedItem>()); }
            byCase.get(f.ParentId).add(f);
            posters.add(f.CreatedById);
        }
        if (byCase.isEmpty()) { return; }

        Map<Id, User> posterById = new Map<Id, User>([SELECT Id, UserType FROM User WHERE Id IN :posters]);
        Map<Id, Case> cases = MaintenanceMessaging.casesForMessaging(byCase.keySet());
        Set<Id> contactIds = new Set<Id>();
        for (Case c : cases.values()) { if (c.ContactId != null) { contactIds.add(c.ContactId); } }
        Map<Id, Id> portalUser = MaintenanceMessaging.portalUsersByContact(contactIds);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Id caseId : byCase.keySet()) {
            Case c = cases.get(caseId);
            if (c == null || !MaintenanceConstants.isMaintenance(c)) { continue; }
            for (FeedItem f : byCase.get(caseId)) {
                User poster = posterById.get(f.CreatedById);
                Boolean internalPoster = poster != null && poster.UserType == 'Standard';
                String text = f.Body == null ? '' : f.Body.stripHtmlTags();
                if (internalPoster && f.CreatedById == c.OwnerId && c.ContactId != null) {
                    emails.add(MaintenanceMessaging.buildEmail(MaintenanceConstants.CUSTOMER_MESSAGE_TEMPLATE, c, text, null));
                    if (portalUser.containsKey(c.ContactId)) {
                        MaintenanceMessaging.notify(MaintenanceConstants.NOTIFICATION_TYPE, 'New message on request ' + c.CaseNumber,
                            text, c.Id, new Set<String>{ portalUser.get(c.ContactId) });
                    }
                } else if (internalPoster) {
                    MaintenanceMessaging.log.add('No customer email for post on ' + c.CaseNumber + ': poster=' + f.CreatedById + ' owner=' + c.OwnerId + ' contact=' + c.ContactId);
                } else if (!internalPoster && String.valueOf(c.OwnerId).startsWith('005')) {
                    MaintenanceMessaging.notify(MaintenanceConstants.NOTIFICATION_TYPE, 'Customer replied on request ' + c.CaseNumber,
                        text, c.Id, new Set<String>{ c.OwnerId });
                }
            }
        }
        MaintenanceMessaging.send(emails);
    }
}
