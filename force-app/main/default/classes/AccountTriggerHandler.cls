public class AccountTriggerHandler extends TriggerHandler {
  public AccountTriggerHandler() {
    super(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.newMap,
      Trigger.oldMap
    );
  }

  public static boolean enabled = true;
  public static boolean isTriggerEnabled() {
    return enabled;
  }

  public static void enableTrigger() {
    enabled = true;
  }

  public static void disableTrigger() {
    enabled = false;
  }

  public override void beforeInsert() {
    AccountBO.assignCPFCNPJToIdentificationNumber(
      (List<Account>) newRecordList
    );
    AccountBO.assignSellerToIntegratedClient((List<Account>) newRecordList);
  }

  public override void afterInsert() {
    //AccountBO.sendCustomerRecordToSAP((List<Account>) newRecordList);
    //se conta juridica, criar contato com os dados da conta
    AccountBO.createMessagingUser(
      (List<Account>) newRecordList,
      new Map<Id, Account>()
    );
  }

  public override void beforeUpdate() {
    AccountBO.assignSellerToIntegratedClient((List<Account>) newRecordList);
  }

  public override void afterUpdate() {
    AccountBO.sendCustomerRecordToSAP((List<Account>) newRecordList);
    AccountBO.createMessagingUser(
      (List<Account>) newRecordList,
      (Map<Id, Account>) oldMap
    );
  }

  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
