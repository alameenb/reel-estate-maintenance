/** CMP-029. The only trigger on FeedItem. */
trigger FeedItemTrigger on FeedItem (after insert) {
    new FeedItemTriggerHandler().afterInsert(Trigger.new);
}
