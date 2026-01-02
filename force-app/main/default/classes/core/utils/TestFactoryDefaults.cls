@IsTest 
public  class TestFactoryDefaults{

    // Para cadastrar um novo padrao para um objeto, use o modelo [ObjectName]Defaults para o nome da classe.
    // para objetos customizados, omita o __c do nome do objeto

    public class AccountDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Account.Name                        => 'Test Account - Default',
                Account.AccountSource               => 'Advertisement',
                Account.AccountNumber               => '33225',
                Account.AnnualRevenue               => 1000,
                Account.Bairro__c                   => 'Bairro Teste',
                Account.BairroCobranca__c           => 'Bairro Teste',
                Account.BairroEntrega__c            => 'Bairro Teste',
                Account.BillingCity                 => 'Sao Paulo',
                Account.BillingStreet               => 'R. Joao Alves',
                Account.BillingCountry              => 'Brasil',
                Account.BillingState                => 'SP',
                Account.BillingPostalCode           => '02925-130',
                Account.CEP__c                      => '02925-130',
                Account.CNPJ__c                     => '12.345.678/9012-34',
                Account.Complemento__c              => '11',
                Account.ComplementoCobranca__c      => '11',
                Account.ComplementoEntrega__c       => '11',
                Account.CPF__c                      => '123.456.789-01',
                Account.DataModificacao__c          => System.now(),
                Account.DataRegistro__c             => System.now(),
                Account.Description                 => 'Teste Descrição',
                Account.Email__c                    => 'email@teste.com.br',
                Account.EmailProcurador__c          => 'email@teste.com.br',
                Account.EstadoInstalacao__c         => 'São Paulo',
                Account.Fax                         => '1112345678',
                Account.IdExternoConsultor__c       => '1112345678',
                Account.IdVirtualOffice__c          => 'klskdjf9-dmz-nf-r93u4-edjl-kdnad',
                Account.IdVirtualOffice2__c         => '0',
                Account.Industry                    => 'Other',
                Account.LoginVirtualOffice__c       => 'login@teste123.com.br',
                Account.Logradouro__c               => 'Rua Teste de teste',
                Account.Municipio__c                => 'Município Teste',
                Account.MunicipioCobranca__c        => 'Município Teste',
                Account.MunicipioEntrega__c         => 'Município Teste',
                Account.MunicipioInstalacao__c      => 'São Paulo',
                Account.NumeroIdentificacao__c      => '12345678901',
                Account.NumeroRegistroProcurador__c => '12345678901',
                Account.NumeroRua__c                => '10',
                Account.NumeroRuaCobranca__c        => '10',
                Account.NumeroRuaEntrega__c         => '10',
                Account.Phone                       => '1112345678',
                Account.Procurador__c               => 'Procurador',
                Account.Rating                      => 'Warm',
                Account.RazaoSocial__c              => 'Razão Social',
                Account.ShippingCity                => 'Sao Paulo',
                Account.ShippingStreet              => 'R. Joao Alves',
                Account.ShippingCountry             => 'Brasil',
                Account.ShippingState               => 'SP',
                Account.ShippingPostalCode          => '02925-130',
                Account.StatusBodyIntegracaoSAP__c  => 'Status Teste',
                Account.SucessoIntegracaoSAP__c     => false,
                Account.TelefoneProcurador__c       => '1112345678',
                Account.TipoUsuario__c              => 0,
                Account.Type                        => 'Other',
                Account.RecordTypeID                => Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ClientePessoaFisica').getRecordTypeId()
            };
        }
    }

    public class PhysicalPersonAccount implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Account.Name                        => 'Test Account - Physical Person',
                Account.AccountSource               => 'Advertisement',
                Account.AccountNumber               => '33225',
                Account.AnnualRevenue               => 1000,
                Account.Bairro__c                   => 'Bairro Teste',
                Account.BairroCobranca__c           => 'Bairro Teste',
                Account.BairroEntrega__c            => 'Bairro Teste',
                Account.BillingCity                 => 'Sao Paulo',
                Account.BillingStreet               => 'R. Joao Alves',
                Account.BillingCountry              => 'Brasil',
                Account.BillingState                => 'SP',
                Account.BillingPostalCode           => '02925-130',
                Account.CEP__c                      => '02925-130',
                Account.Complemento__c              => '11',
                Account.ComplementoCobranca__c      => '11',
                Account.ComplementoEntrega__c       => '11',
                Account.CPF__c                      => '123.456.789-01',
                Account.DataModificacao__c          => System.now(),
                Account.DataRegistro__c             => System.now(),
                Account.Description                 => 'Teste Descrição',
                Account.Email__c                    => 'email@teste.com.br',
                Account.EmailProcurador__c          => 'email@teste.com.br',
                Account.EstadoInstalacao__c         => 'São Paulo',
                Account.Fax                         => '1112345678',
                Account.IdExternoConsultor__c       => '1112345678',
                Account.IdVirtualOffice__c          => 'klskdjf9-dmz-nf-r93u4-edjl-kdnad',
                Account.IdVirtualOffice2__c         => '0',
                Account.Industry                    => 'Other',
                Account.LoginVirtualOffice__c       => 'login@teste123.com.br',
                Account.Logradouro__c               => 'Rua Teste de teste',
                Account.Municipio__c                => 'Município Teste',
                Account.MunicipioCobranca__c        => 'Município Teste',
                Account.MunicipioEntrega__c         => 'Município Teste',
                Account.MunicipioInstalacao__c      => 'São Paulo',
                Account.NumeroIdentificacao__c      => '12345678901',
                Account.NumeroRegistroProcurador__c => '12345678901',
                Account.NumeroRua__c                => '10',
                Account.NumeroRuaCobranca__c        => '10',
                Account.NumeroRuaEntrega__c         => '10',
                Account.Phone                       => '1112345678',
                Account.Procurador__c               => 'Procurador',
                Account.Rating                      => 'Warm',
                Account.RazaoSocial__c              => 'Razão Social',
                Account.ShippingCity                => 'Sao Paulo',
                Account.ShippingStreet              => 'R. Joao Alves',
                Account.ShippingCountry             => 'Brasil',
                Account.ShippingState               => 'SP',
                Account.ShippingPostalCode          => '02925-130',
                Account.StatusBodyIntegracaoSAP__c  => 'Status Teste',
                Account.SucessoIntegracaoSAP__c     => false,
                Account.TelefoneProcurador__c       => '1112345678',
                Account.TipoUsuario__c              => 0,
                Account.Type                        => 'Other',
                Account.RecordTypeID                => Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ClientePessoaFisica').getRecordTypeId()
            };
        }
    }

    public class LegalPersonAccount implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Account.Name                        => 'Test Account - Legal Person',
                Account.AccountSource               => 'Advertisement',
                Account.AccountNumber               => '33225',
                Account.AnnualRevenue               => 1000,
                Account.Bairro__c                   => 'Bairro Teste',
                Account.BairroCobranca__c           => 'Bairro Teste',
                Account.BairroEntrega__c            => 'Bairro Teste',
                Account.BillingCity                 => 'Sao Paulo',
                Account.BillingStreet               => 'R. Joao Alves',
                Account.BillingCountry              => 'Brasil',
                Account.BillingState                => 'SP',
                Account.BillingPostalCode           => '02925-130',
                Account.CEP__c                      => '02925-130',
                Account.CNPJ__c                     => '12.345.678/9012-34',
                Account.Complemento__c              => '11',
                Account.ComplementoCobranca__c      => '11',
                Account.ComplementoEntrega__c       => '11',
                Account.DataModificacao__c          => System.now(),
                Account.DataRegistro__c             => System.now(),
                Account.Description                 => 'Teste Descrição',
                Account.Email__c                    => 'email@teste.com.br',
                Account.EmailProcurador__c          => 'email@teste.com.br',
                Account.EstadoInstalacao__c         => 'São Paulo',
                Account.Fax                         => '1112345678',
                Account.IdExternoConsultor__c       => '1112345678',
                Account.IdVirtualOffice__c          => 'klskdjf9-dmz-nf-r93u4-edjl-kdnad',
                Account.Industry                    => 'Other',
                Account.LoginVirtualOffice__c       => 'login@teste123.com.br',
                Account.Logradouro__c               => 'Rua Teste de teste',
                Account.Municipio__c                => 'Município Teste',
                Account.MunicipioCobranca__c        => 'Município Teste',
                Account.MunicipioEntrega__c         => 'Município Teste',
                Account.MunicipioInstalacao__c      => 'São Paulo',
                Account.NumeroIdentificacao__c      => '12345678901',
                Account.NumeroRegistroProcurador__c => '12345678901',
                Account.NumeroRua__c                => '10',
                Account.NumeroRuaCobranca__c        => '10',
                Account.NumeroRuaEntrega__c         => '10',
                Account.Phone                       => '1112345678',
                Account.Procurador__c               => 'Procurador',
                Account.Rating                      => 'Warm',
                Account.RazaoSocial__c              => 'Razão Social',
                Account.ShippingCity                => 'Sao Paulo',
                Account.ShippingStreet              => 'R. Joao Alves',
                Account.ShippingCountry             => 'Brasil',
                Account.ShippingState               => 'SP',
                Account.ShippingPostalCode          => '02925-130',
                Account.StatusBodyIntegracaoSAP__c  => 'Status Teste',
                Account.SucessoIntegracaoSAP__c     => false,
                Account.TelefoneProcurador__c       => '1112345678',
                Account.TipoUsuario__c              => 0,
                Account.Type                        => 'Other',
                Account.RecordTypeID                => Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('ClientePessoaJuridica').getRecordTypeId()
            };
        }
    }

    public class ConsultorDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Consultor__c.Name                       => 'Teste Consultor - Default',
                Consultor__c.Ativo__c                   => true,
                Consultor__c.Bairro__c                  => 'Bairro Teste',
                Consultor__c.Bairro_da_Unidade__c       => 'Bairro Teste',
                Consultor__c.BairroCobranca__c          => 'Bairro Teste',
                Consultor__c.BairroEntrega__c           => 'Bairro Teste',
                Consultor__c.Celular__c                 => '11123456789',
                Consultor__c.CEP__c                     => '12345678',
                Consultor__c.CEP_da_Unidade__c          => '23456789',
                Consultor__c.CidadeCobranca__c          => 'São Paulo',
                Consultor__c.CidadeEntrega__c           => 'São Paulo',
                Consultor__c.Complemento__c             => 'Teste',
                Consultor__c.CNPJ__c                    => '12.345.678/9012-34',
                Consultor__c.CodigoPostalCobranca__c    => '00000000',
                Consultor__c.CodigoPostalEntrega__c     => '99999999',
                Consultor__c.Comissao__c                => 45,
                Consultor__c.Complemento__c             => '999',
                Consultor__c.ComplementoCobranca__c     => '999',
                Consultor__c.ComplementoEntrega__c      => '999',
                Consultor__c.CPF__c                     => '123.456.789-01',
                Consultor__c.Descricao__c               => 'Descrição Teste',
                Consultor__c.Email__c                   => 'emailconsultor@teste.com',
                Consultor__c.EmailUnidade__c            => 'emailunidadeconsultor@teste.com',
                Consultor__c.Estado__c                  => 'São Paulo SP',
                Consultor__c.Estado_da_Unidade__c       => 'São Paulo (SP)',
                Consultor__c.EstadoCobranca__c          => 'SP',
                Consultor__c.EstadoEntrega__c           => 'SP',
                Consultor__c.Fax__c                     => '11123456878',
                Consultor__c.IdVirtualOffice__c         => 'las-kdr-84uit-hkdgk-sdnfq-3040',
                Consultor__c.IdVirtualOffice2__c        => '0',
                Consultor__c.Login_no_virtual__c        => 'logintesteconsultor@teste.com',
                Consultor__c.Logradouro__c              => 'Rua Teste',
                Consultor__c.LogradouroDaUnidade__c     => 'Rua Teste',
                Consultor__c.Municipio__c               => 'São Paulo',
                Consultor__c.Municipio_da_Unidade__c    => 'São Paulo',
                Consultor__c.MunicipioCobranca__c       => 'São Paulo',
                Consultor__c.MunicipioEntrega__c        => 'São Paulo',
                Consultor__c.NumeroIdentificacao__c     => '1234567891',
                Consultor__c.NumeroRuaCobranca__c       => '10',
                Consultor__c.NumeroRuaEntrega__c        => '10',
                Consultor__c.Observacoes__c             => '10',
                Consultor__c.PaisCobranca__c            => 'Brasil',
                Consultor__c.PaisEntrega__c             => 'Brasil',
                Consultor__c.RazaoSocial__c             => 'Teste Razao Social',
                Consultor__c.RuaCobranca__c             => 'Rua Teste',
                Consultor__c.RuaEntrega__c              => 'Rua Teste',
                Consultor__c.StatusBodyIntegracaoSAP__c => 'Status Teste',
                Consultor__c.SucessoIntegracaoSAP__c    => false,
                Consultor__c.Telefone__c                => '1112345678',
                Consultor__c.Telefone_da_Unidade__c     => '1134567890',
                Consultor__c.Website__c                 => 'site.teste.com.br',
                Consultor__c.RecordTypeId               => Schema.SObjectType.Consultor__c.getRecordTypeInfosByDeveloperName().get('Consultor').getRecordTypeId()
            };
        }
    }

    public class FranchisedSeller implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Consultor__c.Name                       => 'Teste Franqueado - Default',
                Consultor__c.Ativo__c                   => true,
                Consultor__c.Bairro__c                  => 'Bairro Teste',
                Consultor__c.Bairro_da_Unidade__c       => 'Bairro Teste',
                Consultor__c.BairroCobranca__c          => 'Bairro Teste',
                Consultor__c.BairroEntrega__c           => 'Bairro Teste',
                Consultor__c.Celular__c                 => '11123456789',
                Consultor__c.CEP__c                     => '12345678',
                Consultor__c.CEP_da_Unidade__c          => '23456789',
                Consultor__c.CidadeCobranca__c          => 'São Paulo',
                Consultor__c.CidadeEntrega__c           => 'São Paulo',
                Consultor__c.Complemento__c             => 'Teste',
                Consultor__c.CNPJ__c                    => '12.345.678/9012-34',
                Consultor__c.CodigoPostalCobranca__c    => '00000000',
                Consultor__c.CodigoPostalEntrega__c     => '99999999',
                Consultor__c.Comissao__c                => 45,
                Consultor__c.Complemento__c             => '999',
                Consultor__c.ComplementoCobranca__c     => '999',
                Consultor__c.ComplementoEntrega__c      => '999',
                Consultor__c.CPF__c                     => '123.456.789-01',
                Consultor__c.Descricao__c               => 'Descrição Teste',
                Consultor__c.Email__c                   => 'emailconsultor@teste.com',
                Consultor__c.EmailUnidade__c            => 'emailunidadeconsultor@teste.com',
                Consultor__c.Estado__c                  => 'São Paulo SP',
                Consultor__c.Estado_da_Unidade__c       => 'São Paulo (SP)',
                Consultor__c.EstadoCobranca__c          => 'SP',
                Consultor__c.EstadoEntrega__c           => 'SP',
                Consultor__c.Fax__c                     => '11123456878',
                Consultor__c.IdVirtualOffice__c         => 'las-kdr-84uit-hkdgk-sdnfq-3040',
                Consultor__c.IdVirtualOffice2__c        => '0',
                Consultor__c.Login_no_virtual__c        => 'logintesteconsultor@teste.com',
                Consultor__c.Logradouro__c              => 'Rua Teste',
                Consultor__c.LogradouroDaUnidade__c     => 'Rua Teste',
                Consultor__c.Municipio__c               => 'São Paulo',
                Consultor__c.Municipio_da_Unidade__c    => 'São Paulo',
                Consultor__c.MunicipioCobranca__c       => 'São Paulo',
                Consultor__c.MunicipioEntrega__c        => 'São Paulo',
                Consultor__c.NumeroIdentificacao__c     => '1234567891',
                Consultor__c.NumeroRuaCobranca__c       => '10',
                Consultor__c.NumeroRuaEntrega__c        => '10',
                Consultor__c.Observacoes__c             => '10',
                Consultor__c.PaisCobranca__c            => 'Brasil',
                Consultor__c.PaisEntrega__c             => 'Brasil',
                Consultor__c.RazaoSocial__c             => 'Teste Razao Social',
                Consultor__c.RuaCobranca__c             => 'Rua Teste',
                Consultor__c.RuaEntrega__c              => 'Rua Teste',
                Consultor__c.StatusBodyIntegracaoSAP__c => 'Status Teste',
                Consultor__c.SucessoIntegracaoSAP__c    => false,
                Consultor__c.Telefone__c                => '1112345678',
                Consultor__c.Telefone_da_Unidade__c     => '1134567890',
                Consultor__c.Website__c                 => 'site.teste.com.br',
                Consultor__c.RecordTypeId               => Schema.SObjectType.Consultor__c.getRecordTypeInfosByDeveloperName().get('Franqueado').getRecordTypeId()
            };
        }
    }

    public class OpportunityDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Opportunity.Name                                        => 'Teste Oportunidade - Default',
                Opportunity.RecordTypeId                                => Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Solar').getRecordTypeId(),
                Opportunity.Acrescimo__c                                => 1,
                Opportunity.Adequacao__c                                => 'Adequação teste',
                Opportunity.AjusteAnualTarifa__c                        => 1,
                Opportunity.Amount                                      => 1,
                Opportunity.AnualSolergo__c                             => 1,
                Opportunity.AreaM__c                                    => 1,
                Opportunity.AumentarDemandaContratadaFP__c              => 'Sim',
                Opportunity.Bairro__c                                   => 'Bairro Teste',
                Opportunity.Budget_Confirmed__c                         => true,
                Opportunity.CEP__c                                      => '12345-678',
                Opportunity.CloseDate                                   => Date.valueOf('2030-01-01'),
                Opportunity.ComentarioSolicitante__c                    => 'Comentário teste',
                Opportunity.Complemento__c                              => 'Complemento teste',
                Opportunity.UF_Concessionaria__c                        => 'SP',
                Opportunity.ConcessionariaEnergia__c                    => 'Eletropaulo - Enel SP - SP',
                Opportunity.CondicoesPagamento__c                       => 'Recursos Próprios',
                Opportunity.ConsumoAlvo__c                              => 1,
                Opportunity.ConsumoAnual__c                             => 1,
                Opportunity.ConsumoAnualConsiderado__c                  => 1,
                Opportunity.ConsumoAnualInformado__c                    => 1,
                Opportunity.ConsumoInformadoB__c                        => 1,
                Opportunity.ConsumoMedioForaPonta__c                    => 1,
                Opportunity.ConsumoMedioMensalB__c                      => 1,
                Opportunity.ConsumoMedioPonta__c                        => 1,
                Opportunity.Contrato_aprovado__c                        => false,
                Opportunity.ContratoGerado__c                           => false,
                Opportunity.CPF_CNPJ__c                                 => '12345678901',
                Opportunity.CustoMedioEnergia__c                        => 1,
                Opportunity.DadosInversor__c                            => 'Dados teste',
                Opportunity.Data__c                                     => Date.valueOf('2022-01-01'),
                Opportunity.DataEntrega__c                              => System.today().addDays(7),
                Opportunity.DataEnvioContrato__c                        => System.today(),
                Opportunity.DataHoraEnvioContrato__c                    => System.now(),
                Opportunity.DemandaContratadaForaPonta__c               => 1,
                Opportunity.DemandaContratadaPonta__c                   => 1,
                Opportunity.DescontoBaseUFV__c                          => 1,
                Opportunity.Description                                 => 'Descrição',
                Opportunity.Direct__c                                   => 1,
                Opportunity.DiscoveryCompleted__c                       => true,
                Opportunity.EconomiaAcumulada__c                        => 1,
                Opportunity.EconomiaAnualEstimada__c                    => 1,
                Opportunity.EconomiaMensalEstimada__c                   => 1,
                Opportunity.EmpresaDistribuicaoEnergia__c               => 'Empresa Teste',
                Opportunity.Endereco__c                                 => 'Endereço Teste',
                Opportunity.EnquadramentoGD__c                          => 'Microgeração',
                Opportunity.EstadoInstalacao__c                         => 'São Paulo',
                Opportunity.EtapaViabilidade__c                         => null,
                Opportunity.FabricanteInversor__c                       => 'Fabricante teste',
                Opportunity.FabricanteModulos__c                        => 'Fabricante teste',
                Opportunity.Financiamento_solicitado__c                 => false,
                Opportunity.ForcaMaximaSistema__c                       => 1,
                Opportunity.ForecastCategoryName                        => 'Omitted',
                Opportunity.GeracaoAnualEstimada__c                     => 1,
                Opportunity.GeracaoDesejadaMensalB__c                   => 1,
                Opportunity.GeracaoMensalEstimada__c                    => 1,
                Opportunity.GrupoTarifario__c                           => 'Grupo A',
                Opportunity.IdVirtualOffice__c                          => 'askjdlkasdj9038094234',
                Opportunity.Inversor_1_Modelo__c                        => 'Modelo teste',
                Opportunity.Inversor_1_Potencia_Nominal__c              => 1,
                Opportunity.Inversor_1_Quantitativo__c                  => 1,
                Opportunity.Inversor_2_Modelo__c                        => 'Modelo teste',
                Opportunity.Inversor_2_Potencia_Nominal__c              => 1,
                Opportunity.Inversor_2_Quantitativo__c                  => 1,
                Opportunity.Inversor_3_Modelo__c                        => 'Modelo teste',
                Opportunity.Inversor_3_Potencia_Nominal__c              => 1,
                Opportunity.Inversor_3_Quantitativo__c                  => 1,
                Opportunity.IsPrivate                                   => false,
                Opportunity.LeadSource                                  => 'Outros',
                Opportunity.LinkContrato__c                             => 'teste.com.br',
                Opportunity.LinkContratoEnviado__c                      => 'teste.com.br',
                Opportunity.Logradouro__c                               => 'Logradouro teste',
                Opportunity.Loss_Reason__c                              => 'Other',
                Opportunity.ModalidadeVenda__c                          => 'Venda Direta - Enerzee',
                Opportunity.Modelo__c                                   => 'Modelo Teste',
                Opportunity.ModeloInversor__c                           => 'Modelo Teste',
                Opportunity.MunicipioInstalacao__c                      => 'São Paulo',
                Opportunity.NextStep                                    => 'Next Step Teste',
                Opportunity.Notificacao7DiasEnviada__c                  => false,
                Opportunity.NumeroContrato__c                           => '1',
                Opportunity.NumeroInversores__c                         => 1,
                Opportunity.NumeroModulos__c                            => 1,
                Opportunity.NumeroPedido__c                             => '1',
                Opportunity.Origem__c                                   => 'Observações Teste',
                Opportunity.Origem__c                                   => null,
                Opportunity.PaybackAno25__c                             => null,
                Opportunity.PaybackAnos__c                              => 1,
                Opportunity.Pesokg__c                                   => 1,
                Opportunity.Pontos__c                                   => 1,
                Opportunity.PontosRS__c                                 => 1,
                Opportunity.PorcentagemAumentoConsumo__c                => 1,
                Opportunity.PotenciaModulos__c                          => '1',
                Opportunity.PotenciaNominalSistema__c                   => 1,
                Opportunity.PotenciaNominalWp__c                        => 1,
                Opportunity.PotenciaPicoSistema__c                      => 1,
                Opportunity.PrazoAprovacaoViabilidade__c                => System.now().addDays(10),
                Opportunity.PrazoEntregaDias__c                         => '3 dias',
                Opportunity.PrazoObraDias__c                            => 1,
                Opportunity.PrecoCA__c                                  => 1,
                Opportunity.PrecoCustosAdicionais__c                    => 1,
                Opportunity.PrecoUFV__c                                 => 1,
                Opportunity.Probability                                 => 1,
                Opportunity.Proposta_aprovada__c                        => false,
                Opportunity.PropostaGerada__c                           => false,
                Opportunity.PropostaTecnicaDinamica__c                  => 'Teste',
                Opportunity.QuinzePorcento__c                           => 1,
                Opportunity.RendimentoMedio__c                          => 1,
                Opportunity.RevisaoFinanceira__c                        => 'Sim',
                Opportunity.ROIAnalysisCompleted__c                     => true,
                Opportunity.Soma__c                                     => 1,
                Opportunity.StageName                                   => 'Prospecção',
                Opportunity.StatusBodyIntegracaoNivello__c              => 'Status teste',
                Opportunity.StatusEnvioContrato__c                      => 'Não enviado',
                Opportunity.SubGrupoTarifario__c                        => 'Sub-Grupo teste',
                Opportunity.SucessoIntegracaoNivello__c                 => false,
                Opportunity.TarifaComTributosB__c                       => 1,
                Opportunity.TarifaDemandaForaPonta__c                   => 1,
                Opportunity.TarifaDemandaPonta__c                       => 1,
                Opportunity.TarifaEnergia__c                            => 1,
                Opportunity.TarifaForaPonta__c                          => 1,
                Opportunity.TarifaPonta__c                              => 1,
                Opportunity.TarifaTributos__c                           => 1,
                Opportunity.TensaoAlimentacao__c                        => '380-220V',
                Opportunity.TipoObraProjeto__c                          => 'UFV Micro',
                Opportunity.TipoTelhadoEstrutura__c                     => 'Ao Solo',
                Opportunity.TipoVenda__c                                => 'Normal',
                Opportunity.TIR__c                                      => 1,
                Opportunity.TotalOpportunityQuantity                    => 1,
                Opportunity.Type                                        => 'Micro Contrato',
                Opportunity.UCBeneficiadora__c                          => 'Teste',
                Opportunity.UCGeradora__c                               => 'Teste',
                Opportunity.ValidadeProposta__c                         => '3 dias',
                Opportunity.ValoresAdicionaisInclusosProposta__c        => 'Valores teste',
                Opportunity.ValorVista__c                               => 1,
                Opportunity.VerbaInstalacao__c                          => 1,
                Opportunity.VPL__c                                      => 1,
                Opportunity.Classificacao__c                            => 'Contratos de Locação',
                Opportunity.NumeroOrigemContrato__c                     => '123',
                Opportunity.Categoria_Fase__c                           => 'Monofásico',
                Opportunity.O_padr_o_ser_readequado__c                  => 'Sim',
                Opportunity.Haver_aumento_de_carga__c                   => 'Sim',
                Opportunity.Refor_o_na_estrutura_necess_rio__c          => 'Sim',
                Opportunity.Posto_de_transforma_o_ou_disponibilidad__c  => 'Sim',
                Opportunity.Estudo_de_estrutura__c                      => 'Sim',
                Opportunity.Aumento_da_potencia_nominal_do_sistema__c   => 'Sim',
                Opportunity.Resultado_da_Viabilidade_Tecnica__c         => 'Positiva',
                Opportunity.Corrente_nominal_do_disjuntor_de_entrada__c => 'teste',
                Opportunity.Secao_Nominal_Bitola_do_cabo__c             => 'teste',
                Opportunity.Estrutura_de_fixacao_verificado_in_loco__c  => 'teste',
                Opportunity.Observacoes_pos_sombreamento__c             => 'teste',
                Opportunity.Observacoes_pos_visita__c                   => 'teste',
                Opportunity.Custos_adicionais_levantados__c             => 'teste',
                Opportunity.Equipe_Propria_ou_Terceira__c               => 'Integrador',
                Opportunity.Duracao_estimada_da_visita_em_minutos__c    => 12,
                Opportunity.TextoEstudo__c                              => 'teste',
                Opportunity.TextoMotivo__c                              => 'teste',
                Opportunity.StatusViabilidade__c                        => 'Inviável'
            };
        }
    }
    
    public class FaturamentoDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
				Faturamento__c.Name => 'Test Faturamento - Default'
            };
        }
    }
    
    public class ProposalCoverDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                ProposalCover__c.Name 				=> 'Test Proposal Cover - Default',
                ProposalCover__c.IsActive__c 		=> true,
                ProposalCover__c.IsDefault__c 		=> true,
                ProposalCover__c.isPromotional__c	=> false,
                ProposalCover__c.GrupoDeProdutos__c	=> 'Solar',
                ProposalCover__c.GrupoTarifario__c 	=> 'Grupo A',
                ProposalCover__c.Template__c 		=> 'ModeloPropostaA'
            };
        }
    }

    public class PartnerDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Parceiro__c.Name 				=> 'Test Parceiro - Default',
                Parceiro__c.Ativo__c 			=> true,
                Parceiro__c.Produto__c 			=> 'Solar',
                Parceiro__c.GrupoTarifario__c	=> 'Grupo A'
            };
        }
    }
    
    public class Product2Defaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Product2.Name                          => 'Test Faturamento - Default',
                Product2.ProductCode                   => 'ITM02654',
                Product2.Id_Externo__c                 => 'ITM02654',
                Product2.Description                   => 'Medidor bidirecional modelo XYZ, fabricante Azurth. Modelo AJK-09856',
                Product2.Family                        => 'SistFotovoltaicos',
                Product2.AdministrarItemPor__c         => 'teste',
                Product2.Altura__c                     => 12,
                Product2.Caracteristica1__c            => 'teste',
                Product2.Caracteristica2__c            => 'teste',
                Product2.Caracteristica3__c            => 'teste',
                Product2.ClassificacaoItensImpostos__c => 'Material',
                Product2.Comprimento__c                => 12,
                Product2.Codigo_de_Barras__c           => '1234567890',
                Product2.DescricaoItem__c              => 'teste',
                Product2.Fabricante__c                 => 'teste',
                Product2.GrupoItens__c                 => 'teste',
                Product2.Grupo_UM__c                   => 'teste',
                Product2.IdentificadorAdicional__c     => 'teste',
                Product2.IsencaoTIPI__c                => 'teste',
                Product2.ItensPorUnidadeVenda__c       => 12,
                Product2.Largura__c                    => 12,
                Product2.Lista_de_Precos__c            => 'teste',
                Product2.NomeUMEmbalagem__c            => 'teste',
                Product2.NomeUMVendas__c               => 'teste',
                Product2.NaoAplicarGruposDescontos__c  => false,
                Product2.NumeroItem__c                 => 'teste',
                Product2.NumerosSerieLote__c           => 'teste',
                Product2.Observacoes__c                => 'teste',
                Product2.Peso__c                       => 12,
                Product2.Preco_Unitario__c             => 12,
                Product2.QuantidadeEmbalagem__c        => 12,
                Product2.SituacaoProduto__c            => 'Ativo',
                Product2.TipoEnvio__c                  => 'teste',
                Product2.TipoRegraAvancada__c          => 'teste',
                Product2.TipoItem__c                   => 'teste',
                Product2.VinculadoRecurso__c           => 'teste',
                Product2.Volume__c                     => 12
            };
        }
    }

    public class Kit_InstalacaoDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Kit_Instalacao__c.NumeroItemSAP__c           => '123456789',
                Kit_Instalacao__c.StatusBodyIntegracaoSAP__c => 'Status Teste',
                Kit_Instalacao__c.SucessoIntegracaoSAP__c    => false,
                Kit_Instalacao__c.ValorKit__c                => 10,
                Kit_Instalacao__c.AniversarioLinha__c        => System.today(),
                Kit_Instalacao__c.Recorrencia__c             => 'Semestral',
                Kit_Instalacao__c.TipoFaturamento__c         => 'Parcelado Medido',
                Kit_Instalacao__c.TipoMedicao__c             => 'Quantidade',
                Kit_Instalacao__c.UnidadeMedidaLocacao__c    => 'Serviço',
                Kit_Instalacao__c.VencimentoBase__c          => System.today(),
                Kit_Instalacao__c.CodigoImposto__c           => 'Manut. Predial'
            };
        }
    }

    public class InstalacaoDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Instalacao__c.ConsultorInstalacao__c => 'Instalação Teste'
            };
        }
    }

    public class OpportunityLineItemDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                OpportunityLineItem.Description => 'Descrição Teste',
                OpportunityLineItem.Discount    => 1,
                OpportunityLineItem.Quantity    => 1,
                OpportunityLineItem.ServiceDate => System.today(),
                OpportunityLineItem.UnitPrice   => 10
            };
        }
    }

    public class Pricebook2Defaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Pricebook2.Name        => 'Test Pricebook - Default',
                Pricebook2.IsActive    => true,
                Pricebook2.Description => 'Descrição teste'
            };
        }
    }

    public class PricebookEntryDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                PricebookEntry.IsActive         => true,
                PricebookEntry.UseStandardPrice => false
            };
        }
    }

    public class AssignedResourceDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                AssignedResource.EstimatedTravelTime                       => 28,
                AssignedResource.FSL__EstimatedTravelDistanceFrom__c       => 21131,
                AssignedResource.FSL__EstimatedTravelDistanceTo__c         => 32838,
                AssignedResource.FSL__EstimatedTravelTimeFrom__c           => 19,
                AssignedResource.FSL__Estimated_Travel_Time_From_Source__c => 'SLR',
                AssignedResource.FSL__Estimated_Travel_Time_To_Source__c   => 'SLR',
                AssignedResource.FSL__Last_Updated_Epoch__c                => Double.valueOf('1671199214058'),
                AssignedResource.FSL__UpdatedByOptimization__c             => false,
                AssignedResource.FSL__calculated_duration__c               => 240
            };
        }
    }

    public class ServiceAppointmentDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                ServiceAppointment.Status            => 'None',
                ServiceAppointment.EarliestStartTime => System.now().addDays(-7),
                ServiceAppointment.DueDate           => System.now().addDays(7),
                ServiceAppointment.SchedStartTime    => System.now().addDays(-7),
                ServiceAppointment.SchedEndTime      => System.now().addDays(7),
                ServiceAppointment.Subject           => 'Teste',
                ServiceAppointment.Description       => 'Teste',
                ServiceAppointment.ActualStartTime   => System.now().addDays(-7),
                ServiceAppointment.ActualEndTime     => System.now().addDays(7)

            };
        }
    }

    public class ServiceResourceDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                ServiceResource.Name            => 'Teste',
                ServiceResource.IsActive        => true,
                ServiceResource.ResourceType    => 'T',
                ServiceResource.OwnerId         => UserInfo.getUserId(),
                ServiceResource.RelatedRecordId => UserInfo.getUserId()
            };
        }
    }

    public class ServiceTerritoryMemberDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                ServiceTerritoryMember.TerritoryType      => 'P',
                ServiceTerritoryMember.EffectiveStartDate => System.now().addDays(-20),
                ServiceTerritoryMember.EffectiveEndDate   => System.now().addDays(20),
                ServiceTerritoryMember.Street             => 'Luciano Muratore',
                ServiceTerritoryMember.City               => 'São Paulo',
                ServiceTerritoryMember.State              => 'SP',
                ServiceTerritoryMember.PostalCode         => '04430-020',
                ServiceTerritoryMember.Country            => 'Brasil'
            };
        }
    }

    public class SchedulingConstraintDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                SchedulingConstraint.MaxNonstandardShiftsPerMonth => 30,
                SchedulingConstraint.MaxShiftsPerDay              => 1,
                SchedulingConstraint.MaxShiftsPerMonth            => 22,
                SchedulingConstraint.MaxShiftsPerWeek             => 5,
                SchedulingConstraint.MaxWorkingHoursPerDay        => 8,
                SchedulingConstraint.MaxWorkingHoursPerMonth      => 220,
                SchedulingConstraint.MaxWorkingHoursPerWeek       => 44,
                SchedulingConstraint.Name                         => 'Horário de almoço',
                SchedulingConstraint.OwnerId                      => UserInfo.getUserId()
            };
        }
    }

    public class ProjetoDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Projeto__c.Name                               => 'Projeto Default',
                Projeto__c.DataContagemPrazo__c               => Date.valueOf('2022-01-01'),
                Projeto__c.DataInicioContrato__c              => Date.valueOf('2022-01-01'),
                Projeto__c.PotenciaSistema__c                 => '12',
                Projeto__c.PrazoContratoDias__c               => 1,
                Projeto__c.Status__c                          => 'Planejamento',
                Projeto__c.TipoObra__c                        => 'UFV Mini até 300',
                Projeto__c.TipoUsina__c                       => 'Solo'
            };
        }
    }

    public class TaskDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                Task.Subject     => 'CONTRATAR INTEGRADOR',
                Task.Description => 'Description Teste',
                Task.Status      => 'Open'
            };
        }
    }

    public class WorkTypeDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                WorkType.Name              => 'Instalação Bombeamento',
                WorkType.EstimatedDuration => 12 
            };
        }
    }

    public class OperatingHoursDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                OperatingHours.Name        => 'Seg - Sex 08:00-17:00hs (GMT5)',
                OperatingHours.Description => 'Descrição Teste',
                OperatingHours.TimeZone    => 'America/Sao_Paulo'
            };
        }
    }

    public class ServiceTerritoryDefaults implements TestFactory.FieldDefaults {
        public Map<Schema.SObjectField, Object> getFieldDefaults() {
            return new Map<Schema.SObjectField, Object> {
                ServiceTerritory.Name     => 'São Paulo',
                ServiceTerritory.IsActive => true
            };
        }
    }
}