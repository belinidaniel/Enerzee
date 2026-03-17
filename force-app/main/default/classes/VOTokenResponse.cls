/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : TokenAPIVOWsTest
 **/
public class VOTokenResponse {
  public String access_token;
  public String token_type;
  public Integer expires_in;

  public static VOTokenResponse parse(String json) {
    return (VOTokenResponse) System.JSON.deserialize(
      json,
      VOTokenResponse.class
    );
  }
}
