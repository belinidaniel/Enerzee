/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 01-05-2026
 * @last modified by  : Daniel Belini
**/
public without sharing class HelpDeskContactDAO {
    public static Contact findByEmail(String email) {
        if (String.isBlank(email)) return null;
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Email, MobilePhone, Phone, AccountId, Verification_Code__c, Verification_Code_Expires__c
            FROM Contact
            WHERE Email = :email
            LIMIT 1
        ];
        return contacts.isEmpty() ? null : contacts[0];
    }

    public static Account findEnerzeeAccount() {
        List<Account> accs = [
            SELECT Id, Name
            FROM Account
            WHERE Name LIKE '%Enerzee%'
            LIMIT 1
        ];
        return accs.isEmpty() ? null : accs[0];
    }

    public static Contact findById(Id contactId) {
        if (contactId == null) return null;
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, Name, Email, MobilePhone, Phone, AccountId
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        return contacts.isEmpty() ? null : contacts[0];
    }

    public static Contact createContact(String email, String firstName, String lastName, String mobilePhone) {
        Account a = findEnerzeeAccount();
        Contact c = new Contact();
        c.Email = email;
        c.FirstName = String.isNotBlank(firstName) ? firstName : 'Visitante';
        c.LastName = String.isNotBlank(lastName) ? lastName : 'Portal';
        c.MobilePhone = mobilePhone;
        c.Phone = mobilePhone;
        c.AccountId = a != null ? a.Id : null;
        insert c;
        return c;
    }

    public static void saveVerification(Contact c, String code, Datetime expiresAt) {
        c.Verification_Code__c = code;
        c.Verification_Code_Expires__c = expiresAt;
        update c;
    }
}