//
//  MercadoPagoCheckout+PaymentFlowHandler.swift
//  MercadoPagoSDK
//
//  Created by Eden Torres on 03/07/2018.
//  Copyright © 2018 MercadoPago. All rights reserved.
//

import Foundation
extension MercadoPagoCheckout: PXPaymentResultHandlerProtocol {
    func finishPaymentFlow(paymentResult: PaymentResult) {
        self.viewModel.paymentResult = paymentResult
        PXAnimatedButton.animateButtonWith(paymentResult: paymentResult)
    }

    func finishPaymentFlow(businessResult: PXBusinessResult) {
        // TODO: Remove
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3), execute: {
        self.viewModel.businessResult = businessResult
        PXAnimatedButton.animateButtonWith(businessResult: businessResult)

        })
    }
}
