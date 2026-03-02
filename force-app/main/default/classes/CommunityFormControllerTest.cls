@isTest
public class CommunityFormControllerTest {
  @testSetup
  static void setup() {
    // Create test data
    Case testCase = new Case();
    testCase.Subject = 'Test Case';
    testCase.Status = 'New';
    testCase.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName()
      .get('Qualificação de Integradores')
      .getRecordTypeId();
    insert testCase;
  }

  @isTest
  static void testCreateCase() {
    // Prepare test data
    Map<String, Object> formData = new Map<String, Object>{
      'mensagem' => 'Test message',
      'nomeFantasia' => 'Test Integrator',
      'email' => 'test@example.com',
      'telefone' => '1234567890',
      'estado' => 'SP',
      'cidade' => 'São Paulo',
      'nomeConsultor' => 'Test Consultant',
      'emailConsultor' => 'consultant@example.com',
      'tornarConsultor' => 'true',
      'cnpj' => '12345678901234',
      'razaoSocial' => 'Test Company',
      'endereco' => 'Test Address',
      'bairro' => 'Test Neighborhood',
      'cep' => '12345678',
      'nomeRepresentante' => 'Test Representative',
      'enderecoRepresentante' => 'Rep Address',
      'bairroRepresentante' => 'Rep Neighborhood',
      'cidadeRepresentante' => 'Rep City',
      'complementoRepresentante' => 'Rep Complement',
      'estadoRepresentante' => 'Rep State',
      'cepRepresentante' => 'Rep CEP',
      'telefoneRepresentante' => '0987654321',
      'emailRepresentante' => 'rep@example.com',
      'cpfRepresentante' => '12345678901',
      'banco' => 'Test Bank',
      'agencia' => '1234',
      'contaCorrente' => '56789',
      'certidaoTrabalhista' => 'Certidao Trabalhista',
      'certidaoCivel' => 'Certidao Civel',
      'certidaoCriminal' => 'Certidao Criminal',
      'certidaoFederal' => 'Certidao Federal',
      'contratoSocial' => 'Contrato Social',
      'docPessoais' => 'Doc Pessoais',
      'portfolioEmpresa' => 'Portfolio Empresa',
      'fotosInstalacoes' => 'Fotos Instalacoes'
    };

    String payload = JSON.serialize(formData);

    Test.startTest();
    Id caseId = CommunityFormController.createCase(payload);
    Test.stopTest();

    // Verify the case was created
    Case createdCase = [
      SELECT
        Id,
        Description,
        Subject,
        Status,
        NomeIntegradorWeb__c,
        EmailIntegradorWeb__c,
        SuppliedPhone,
        Estado__c,
        Cidade__c,
        NomeConsultorWeb__c,
        EmailConsultorWeb__c,
        DesejaSeTornarConsultor__c,
        PaisIntegrador__c
      FROM Case
      WHERE Id = :caseId
    ];
    System.assertEquals('Brasil', createdCase.PaisIntegrador__c);
  }

  @isTest
  static void testSaveFile() {
    // Prepare test data
    Map<String, Object> fileDataMap = new Map<String, Object>{
      'name' => 'TestFile.txt',
      'content' => EncodingUtil.base64Encode(Blob.valueOf('Test file content'))
    };

    Case testCase = [SELECT Id FROM Case LIMIT 1];

    Test.startTest();
    Id contentVersionId = CommunityFormController.saveFile(
      fileDataMap,
      testCase.Id
    );
    Test.stopTest();

    // Verify the file was saved
    ContentVersion contentVersion = [
      SELECT Id, Title, VersionData
      FROM ContentVersion
      WHERE Id = :contentVersionId
    ];
  }
}
