@IsTest
public class CheckBusinessHourTest {
  static testMethod void makeGetCalloutTest() {
    BusinessHours bhs = [
      SELECT id, Name
      FROM BusinessHours
      WHERE IsDefault = TRUE
      LIMIT 1
    ];
    List<String> bhName = new List<String>();
    bhName.add(bhs.Name);
    CheckBusinessHour.makeGetCallout(bhName);
  }
}
