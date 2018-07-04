//
//  MercadoPagoCheckoutScreens.swift
//  MercadoPagoSDK
//
//  Created by Eden Torres on 7/18/17.
//  Copyright © 2017 MercadoPago. All rights reserved.
//

import Foundation

extension MercadoPagoCheckout {

    func showPaymentMethodsScreen() {

        self.viewModel.paymentData.clearCollectedData()

        // If paymentMethodsPlugins is available, disable discounts.
        if (!viewModel.paymentMethodPlugins.isEmpty || viewModel.paymentPlugin != nil) && viewModel.paymentData.discount == nil {
            MercadoPagoCheckoutViewModel.flowPreference.disableDiscount()
        }

        let paymentMethodSelectionStep = PaymentVaultViewController(viewModel: self.viewModel.paymentVaultViewModel(), callback: { [weak self] (paymentOptionSelected: PaymentMethodOption) -> Void  in

            guard let strongSelf = self else {
                return
            }

            strongSelf.viewModel.updateCheckoutModel(paymentOptionSelected: paymentOptionSelected)
            strongSelf.viewModel.rootVC = false
            strongSelf.executeNextStep()
        })
        self.pxNavigationHandler.pushViewController(viewController: paymentMethodSelectionStep, animated: true)

    }
    func showCardForm() {
        let cardFormStep = CardFormViewController(cardFormManager: self.viewModel.cardFormManager(), callback: { [weak self](paymentMethods, cardToken) in

            guard let strongSelf = self else {
                return
            }

            strongSelf.viewModel.updateCheckoutModel(paymentMethods: paymentMethods, cardToken: cardToken)
            strongSelf.executeNextStep()
        })
        self.pxNavigationHandler.pushViewController(viewController: cardFormStep, animated: true)
    }

    func showIdentificationScreen() {
        let identificationStep = IdentificationViewController (identificationTypes: self.viewModel.identificationTypes!, callback: { [weak self] (identification : Identification) in
            guard let strongSelf = self else {
                return
            }

            strongSelf.viewModel.updateCheckoutModel(identification: identification)
            strongSelf.executeNextStep()
            }, errorExitCallback: { [weak self] in
                self?.finish()
        })

        identificationStep.callbackCancel = {[weak self] in
            self?.pxNavigationHandler.navigationController.popViewController(animated: true)
        }
        self.pxNavigationHandler.pushViewController(viewController: identificationStep, animated: true)
    }

    func showPayerInfoFlow() {
        let viewModel = self.viewModel.payerInfoFlow()
        let vc = PayerInfoViewController(viewModel: viewModel) { [weak self] (payer) in

            guard let strongSelf = self else {
                return
            }

            strongSelf.viewModel.updateCheckoutModel(payer: payer)
            strongSelf.executeNextStep()
        }
        self.pxNavigationHandler.pushViewController(viewController: vc, animated: true)
    }

    func showIssuersScreen() {
        let issuerStep = AdditionalStepViewController(viewModel: self.viewModel.issuerViewModel(), callback: { [weak self](issuer) in

            guard let issuer = issuer as? Issuer else {
                fatalError("Cannot convert issuer to type Issuer")
            }

            self?.viewModel.updateCheckoutModel(issuer: issuer)
            self?.executeNextStep()

        })

        self.pxNavigationHandler.pushViewController(viewController: issuerStep, animated: true)
    }

    func showPayerCostScreen() {
        let payerCostViewModel = self.viewModel.payerCostViewModel()

        let payerCostStep = AdditionalStepViewController(viewModel: payerCostViewModel, callback: { [weak self] (payerCost) in
            guard let payerCost = payerCost as? PayerCost else {
                fatalError("Cannot convert payerCost to type PayerCost")
            }

            self?.viewModel.updateCheckoutModel(payerCost: payerCost)
            self?.executeNextStep()
        })

        weak var strongPayerCostViewController = payerCostStep

        payerCostStep.viewModel.couponCallback = {[weak self] (discount) in
            guard let strongSelf = self else {
                return
            }
           // strongSelf.viewModel.paymentData.discount = discount TODO SET DISCOUNT WITH CAMPAIGN

            strongSelf.getPayerCosts(updateCallback: {

                guard let payerCosts = strongSelf.viewModel.payerCosts, let payerCostViewController = strongPayerCostViewController else {
                    return
                }

                payerCostViewController.updateDataSource(dataSource: payerCosts)
            })

        }
        self.pxNavigationHandler.pushViewController(viewController: payerCostStep, animated: true)
    }

    func showReviewAndConfirmScreen() {

        let reviewVC = PXReviewViewController(viewModel: self.viewModel.reviewConfirmViewModel(), callbackPaymentData: { [weak self] (paymentData: PaymentData) in
            guard let strongSelf = self else {
                return
            }

            strongSelf.viewModel.updateCheckoutModel(paymentData: paymentData)

            if !paymentData.hasPaymentMethod() && MercadoPagoCheckoutViewModel.changePaymentMethodCallback != nil {
                MercadoPagoCheckoutViewModel.changePaymentMethodCallback!()
            }
            strongSelf.executeNextStep()

        }, callbackConfirm: { [weak self] (paymentData: PaymentData) in

            guard let strongSelf = self else {
                return
            }

            strongSelf.viewModel.updateCheckoutModel(paymentData: paymentData)

            if MercadoPagoCheckoutViewModel.paymentDataConfirmCallback != nil {
                MercadoPagoCheckoutViewModel.paymentDataCallback = MercadoPagoCheckoutViewModel.paymentDataConfirmCallback
                strongSelf.finish()
            } else {
                strongSelf.executeNextStep()
            }

        }, callbackExit: { [weak self] () -> Void in
            guard let strongSelf = self else {
                return
            }

            strongSelf.cancel()
            }, finishButtonAnimation: {
                self.executeNextStep()
        })

        self.pxNavigationHandler.pushViewController(viewController: reviewVC, animated: true)
    }

    func showSecurityCodeScreen() {

        let securityCodeVc = SecurityCodeViewController(viewModel: self.viewModel.savedCardSecurityCodeViewModel(), collectSecurityCodeCallback: { [weak self] (cardInformation: CardInformationForm, securityCode: String) -> Void in
            self?.createCardToken(cardInformation: cardInformation as? CardInformation, securityCode: securityCode)
        })
        self.pxNavigationHandler.pushViewController(viewController: securityCodeVc, animated: true, backToFirstPaymentVault: true)
    }

    func collectSecurityCodeForRetry() {
        let securityCodeVc = SecurityCodeViewController(viewModel: self.viewModel.cloneTokenSecurityCodeViewModel(), collectSecurityCodeCallback: { [weak self] (cardInformation: CardInformationForm, securityCode: String) -> Void in
            guard let token = cardInformation as? Token else {
                fatalError("Cannot convert cardInformation to Token")
            }
            self?.cloneCardToken(token: token, securityCode: securityCode)

        })
        self.pxNavigationHandler.pushViewController(viewController: securityCodeVc, animated: true)

    }

    func showPaymentResultScreen() {

        _ = self.viewModel.saveOrDeleteESC()

        if self.viewModel.businessResult != nil {
            self.showBusinessResultScreen()
            return
        }
        if self.viewModel.paymentResult == nil {
            self.viewModel.paymentResult = PaymentResult(payment: self.viewModel.payment!, paymentData: self.viewModel.paymentData)
        }

        var congratsViewController: MercadoPagoUIViewController

        congratsViewController = PXResultViewController(viewModel: self.viewModel.resultViewModel(), callback: {[weak self] (state: PaymentResult.CongratsState) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.pxNavigationHandler.navigationController.setNavigationBarHidden(false, animated: false)
            if state == PaymentResult.CongratsState.call_FOR_AUTH {
                strongSelf.viewModel.prepareForClone()
                strongSelf.collectSecurityCodeForRetry()
            } else if state == PaymentResult.CongratsState.cancel_RETRY || state == PaymentResult.CongratsState.cancel_SELECT_OTHER {
                strongSelf.viewModel.prepareForNewSelection()
                strongSelf.executeNextStep()

            } else {
                strongSelf.finish()
            }
        })
        //self.pxNavigationHandler.pushViewController(viewController: congratsViewController, animated: false)
        self.pxNavigationHandler.pushViewController(viewController: congratsViewController, animated: false)

    }

    func showBusinessResultScreen() {

        guard let businessResult = self.viewModel.businessResult else {
            return
        }
        let viewModel = PXBusinessResultViewModel(businessResult: businessResult, paymentData: self.viewModel.paymentData, amountHelper: self.viewModel.amountHelper)
        let congratsViewController = PXResultViewController(viewModel: viewModel) { _ in}
        self.pxNavigationHandler.pushViewController(viewController: congratsViewController, animated: false)

    }

    func showErrorScreen() {
        pxNavigationHandler.showErrorScreen(error: MercadoPagoCheckoutViewModel.error, callbackCancel: finish, errorCallback: self.viewModel.errorCallback)
        MercadoPagoCheckoutViewModel.error = nil

    }

    func showFinancialInstitutionsScreen() {
        if let financialInstitutions = self.viewModel.paymentData.getPaymentMethod()!.financialInstitutions {
            self.viewModel.financialInstitutions = financialInstitutions

            if financialInstitutions.count == 1 {
                self.viewModel.updateCheckoutModel(financialInstitution: financialInstitutions[0])
                self.executeNextStep()
            } else {
                let financialInstitutionStep = AdditionalStepViewController(viewModel:
                    self.viewModel.financialInstitutionViewModel(), callback: { [weak self] (financialInstitution) in
                        guard let financialInstitution = financialInstitution as? FinancialInstitution else {
                            fatalError("Cannot convert entityType to type EntityType")
                        }
                        self?.viewModel.updateCheckoutModel(financialInstitution: financialInstitution)
                        self?.executeNextStep()
                })

                financialInstitutionStep.callbackCancel = {[weak self] in
                    guard let object = self else {
                        return
                    }
                    object.viewModel.financialInstitutions = nil
                    object.viewModel.paymentData.transactionDetails?.financialInstitution = nil
                    self?.pxNavigationHandler.navigationController.popViewController(animated: true)
                }

                self.pxNavigationHandler.pushViewController(viewController: financialInstitutionStep, animated: true)
            }
        }
    }

    func showEntityTypesScreen() {
        let entityTypes = viewModel.getEntityTypes()

        self.viewModel.entityTypes = entityTypes

        if entityTypes.count == 1 {
            self.viewModel.updateCheckoutModel(entityType: entityTypes[0])
            self.executeNextStep()
        }

        let entityTypeStep = AdditionalStepViewController(viewModel: self.viewModel.entityTypeViewModel(), callback: { [weak self]  (entityType) in

            guard let entityType = entityType as? EntityType else {
                fatalError("Cannot convert entityType to type EntityType")
            }

            self?.viewModel.updateCheckoutModel(entityType: entityType)
            self?.executeNextStep()
        })

        entityTypeStep.callbackCancel = {[weak self] in
            guard let object = self else {
                return
            }
            object.viewModel.entityTypes = nil
            object.viewModel.paymentData.payer?.entityType = nil
            self?.pxNavigationHandler.navigationController.popViewController(animated: true)
        }

        self.pxNavigationHandler.pushViewController(viewController: entityTypeStep, animated: true)
    }

    func startOneTapFlow() {
        guard let search = viewModel.search, let paymentOtionSelected = viewModel.paymentOptionSelected else {
            return
        }

        var paymentMethodPaymentPlugin: PXPaymentPluginComponent?
        if let plugin = paymentOtionSelected as? PXPaymentMethodPlugin {
            paymentMethodPaymentPlugin = plugin.paymentPlugin
        }

        let paymentFlow = PXPaymentFlow(paymentPlugin: viewModel.paymentPlugin, paymentMethodPaymentPlugin: paymentMethodPaymentPlugin, navigationHandler: pxNavigationHandler, binaryMode: viewModel.binaryMode, mercadoPagoServicesAdapter: viewModel.mercadoPagoServicesAdapter, paymentErrorHandler: self)

        let onetapFlow = OneTapFlow(navigationController: pxNavigationHandler, paymentData: viewModel.paymentData, checkoutPreference: viewModel.checkoutPreference, search: search, paymentOptionSelected: paymentOtionSelected, reviewScreenPreference: viewModel.reviewScreenPreference, oneTapResultHandler: self)

        onetapFlow.setPaymentFlow(paymentFlow: paymentFlow)
        onetapFlow.start()
    }
}
