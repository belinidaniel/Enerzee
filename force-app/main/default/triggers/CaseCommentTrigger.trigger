trigger CaseCommentTrigger on CaseComment(after insert) {
  if (CaseCommentTriggerHandler.isTriggerEnabled()) {
    new CaseCommentTriggerHandler().execute();
  }
}
