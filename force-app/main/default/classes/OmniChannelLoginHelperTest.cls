/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
public class OmniChannelLoginHelperTest {
  @IsTest
  private static void shouldSetUserPresence() {
    OmniChannelLoginHelper.setUserPresence(
      new List<Id>{ UserInfo.getUserId() }
    );
  }
}
