/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : ClickSignDTOTest
 **/
public with sharing class ClickSignDTO {
  public class RequestCreateEnvelop {
    public String name;
    public String locale;
    public Boolean auto_close;
    public Integer remind_interval;
    public String deadline_at;
    public String default_subject;
    public String default_message;
  }
}
