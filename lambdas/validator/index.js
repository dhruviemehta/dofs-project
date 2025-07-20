exports.handler = async (event) => {
    console.log('Validator - Received event:', JSON.stringify(event, null, 2));
    
    try {
        const orderData = event;
        
        // Validation rules
        const validationErrors = [];
        
        // Required fields validation
        if (!orderData.orderId) {
            validationErrors.push('Order ID is required');
        }
        
        if (!orderData.customerId) {
            validationErrors.push('Customer ID is required');
        }
        
        if (!orderData.productId) {
            validationErrors.push('Product ID is required');
        }
        
        if (!orderData.quantity || orderData.quantity <= 0) {
            validationErrors.push('Quantity must be a positive number');
        }
        
        if (!orderData.price || orderData.price <= 0) {
            validationErrors.push('Price must be a positive number');
        }
        
        // Business rules validation
        if (orderData.quantity > 100) {
            validationErrors.push('Quantity cannot exceed 100 items per order');
        }
        
        if (orderData.price > 10000) {
            validationErrors.push('Price cannot exceed $10,000 per order');
        }
        
        // Customer ID format validation (assuming format: CUST-XXXX)
        if (orderData.customerId && !orderData.customerId.match(/^CUST-\d{4,}$/)) {
            validationErrors.push('Customer ID must be in format CUST-XXXX');
        }
        
        // Product ID format validation (assuming format: PROD-XXXX)
        if (orderData.productId && !orderData.productId.match(/^PROD-\d{4,}$/)) {
            validationErrors.push('Product ID must be in format PROD-XXXX');
        }
        
        if (validationErrors.length > 0) {
            console.log('Validation failed:', validationErrors);
            
            const error = new Error('Validation failed');
            error.validationErrors = validationErrors;
            error.orderData = orderData;
            throw error;
        }
        
        console.log('Validation successful for order:', orderData.orderId);
        
        // Return validated order data with additional computed fields
        const validatedOrder = {
            ...orderData,
            totalAmount: orderData.quantity * orderData.price,
            validatedAt: new Date().toISOString(),
            validationStatus: 'PASSED'
        };
        
        return validatedOrder;
        
    } catch (error) {
        console.error('Validation error:', error);
        
        // For Step Functions, we need to throw an error that includes the original order data
        const validationError = {
            error: 'VALIDATION_FAILED',
            message: error.message,
            validationErrors: error.validationErrors || [error.message],
            orderData: error.orderData || event,
            timestamp: new Date().toISOString()
        };
        
        throw validationError;
    }
};
