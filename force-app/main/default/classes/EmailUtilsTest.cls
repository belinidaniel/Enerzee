@isTest
public class EmailUtilsTest {
    @isTest
    static void createSingleEmailMessageTest(){
        EmailUtils.createSingleEmailMessage(
            'Subject',
            'Body',
            new String[]{'teste@teste.com'},
            new String[]{'teste@teste.com'}
        );
    }
}