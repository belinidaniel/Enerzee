/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : AssignedResourceTriggerTest
 **/
public class AssignedResourceTriggerHandler extends TriggerHandler {
  public AssignedResourceTriggerHandler() {
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
  }
  public override void afterInsert() {
    AssignedResourceBO.assignServiceResourceToAppointmentVisitAssignee(
      (List<AssignedResource>) newRecordList
    );
  }

  public override void beforeUpdate() {
  }
  public override void afterUpdate() {
  }

  public override void beforeDelete() {
  }
  public override void afterDelete() {
  }
}
