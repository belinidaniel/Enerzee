/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : NivelloTokenTest
 **/
public class NivelloTokenRequest {
  public String login;
  public String password;

  public static NivelloTokenRequest parse(String json) {
    return (NivelloTokenRequest) System.JSON.deserialize(
      json,
      NivelloTokenRequest.class
    );
  }
}
