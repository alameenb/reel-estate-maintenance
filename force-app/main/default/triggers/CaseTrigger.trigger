/** CMP-008. The only trigger on Case; dispatches to CaseTriggerHandler. */
trigger CaseTrigger on Case (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    CaseTriggerHandler handler = new CaseTriggerHandler();
    switch on Trigger.operationType {
        when AFTER_INSERT { handler.afterInsert(Trigger.new); }
        when AFTER_UPDATE { handler.afterUpdate(Trigger.new, (Map<Id, Case>) Trigger.oldMap); }
        when else { }
    }
}
