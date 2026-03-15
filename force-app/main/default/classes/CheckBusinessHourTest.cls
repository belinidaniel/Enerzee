/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
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
