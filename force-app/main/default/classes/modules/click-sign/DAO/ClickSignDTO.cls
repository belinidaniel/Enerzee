public with sharing class ClickSignDTO {
    
    public class RequestCreateEnvelop{
        public String name;
        public String locale;
        public Boolean auto_close;
        public Integer remind_interval;
        public String deadline_at;
        public String default_subject;
        public String default_message;
    }

}