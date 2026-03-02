@IsTest
public class OmniChannelLoginHelperTest {
  @IsTest
  private static void shouldSetUserPresence() {
    OmniChannelLoginHelper.setUserPresence(
      new List<Id>{ UserInfo.getUserId() }
    );
  }
}
