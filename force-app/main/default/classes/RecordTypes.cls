/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-30-2026
 * @last modified by  : Daniel Belini
 * @test              : KitInstalacaoBOTest, KitInstalacaoTriggerTest
 **/
public class RecordTypes {
    public static Id OPORTUNIDADE_CONTRATO_MICRO {
        get {
            return Schema.SObjectType.Opportunity
                .getRecordTypeInfosByDeveloperName()
                .get('Contrato_Micro')
                .getRecordTypeId();
        }
    }
}
