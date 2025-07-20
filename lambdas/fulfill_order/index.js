const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, UpdateCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');

// AWS SDK will automatically detect the region from the Lambda execution environment
const dynamoClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoClient);

exports.handler = async (event) => {
    console.log('Fulfill Order - Received event:', JSON.stringify(event, null, 2));

    // Process SQS records
    const results = [];

    for (const record of event.Records) {
        try {
            const messageBody = JSON.parse(record.body);
            console.log('Processing order:', messageBody.orderId);

            // Simulate fulfillment process with configurable success rate
            const successRate = parseFloat(process.env.FULFILLMENT_SUCCESS_RATE || '0.7');
            const random = Math.random();
            const isSuccess = random < successRate;

            console.log(`Fulfillment simulation: random=${random}, successRate=${successRate}, success=${isSuccess}`);

            if (isSuccess) {
                // Successful fulfillment
                await updateOrderStatus(messageBody.orderId, 'FULFILLED', {
                    fulfillment_timestamp: new Date().toISOString(),
                    fulfillment_details: {
                        tracking_number: generateTrackingNumber(),
                        carrier: 'EXPRESS_SHIPPING',
                        estimated_delivery: getEstimatedDelivery()
                    }
                });

                console.log('Order fulfilled successfully:', messageBody.orderId);
                results.push({ orderId: messageBody.orderId, status: 'FULFILLED' });

            } else {
                // Failed fulfillment - this will trigger retry/DLQ
                const error = new Error(`Fulfillment failed for order ${messageBody.orderId}`);
                error.orderData = messageBody;
                console.error('Fulfillment failed:', error.message);
                throw error;
            }

        } catch (error) {
            console.error('Error processing record:', error);

            // Check if this is the final attempt (from DLQ perspective)
            const receiveCount = parseInt(record.attributes.ApproximateReceiveCount || '1');
            const maxReceiveCount = parseInt(process.env.DLQ_MAX_RECEIVE_COUNT || '3');

            if (receiveCount >= maxReceiveCount) {
                // This will go to DLQ, so save to failed_orders table
                try {
                    const messageBody = JSON.parse(record.body);
                    await saveFailedOrder(messageBody, error.message, receiveCount);
                    console.log('Failed order saved to failed_orders table:', messageBody.orderId);
                } catch (saveError) {
                    console.error('Error saving failed order:', saveError);
                }
            }

            // Re-throw to trigger SQS retry/DLQ behavior
            throw error;
        }
    }

    return {
        statusCode: 200,
        processedRecords: results.length,
        results
    };
};

async function updateOrderStatus(orderId, status, additionalFields = {}) {
    const updateParams = {
        TableName: process.env.ORDERS_TABLE_NAME,
        Key: { order_id: orderId },
        UpdateExpression: 'SET #status = :status, updated_at = :updated_at',
        ExpressionAttributeNames: { '#status': 'status' },
        ExpressionAttributeValues: {
            ':status': status,
            ':updated_at': new Date().toISOString()
        }
    };

    // Add additional fields to update expression
    if (Object.keys(additionalFields).length > 0) {
        let expressionParts = [];

        Object.entries(additionalFields).forEach(([key, value], index) => {
            const attrName = `#attr${index}`;
            const attrValue = `:val${index}`;

            expressionParts.push(`${attrName} = ${attrValue}`);
            updateParams.ExpressionAttributeNames[attrName] = key;
            updateParams.ExpressionAttributeValues[attrValue] = value;
        });

        updateParams.UpdateExpression += ', ' + expressionParts.join(', ');
    }

    const command = new UpdateCommand(updateParams);
    await docClient.send(command);
}

async function saveFailedOrder(orderData, errorMessage, receiveCount) {
    const failedOrderItem = {
        order_id: orderData.orderId,
        customer_id: orderData.customerId,
        product_id: orderData.productId,
        quantity: orderData.quantity,
        price: orderData.price,
        total_amount: orderData.totalAmount,
        original_timestamp: orderData.timestamp,
        failed_timestamp: new Date().toISOString(),
        error_message: errorMessage,
        receive_count: receiveCount,
        failure_reason: 'FULFILLMENT_PROCESSING_FAILED'
    };

    // Update main orders table to FAILED status
    await updateOrderStatus(orderData.orderId, 'FAILED', {
        failure_reason: 'FULFILLMENT_PROCESSING_FAILED',
        failure_timestamp: new Date().toISOString(),
        error_message: errorMessage
    });

    // Save to failed_orders table
    const command = new PutCommand({
        TableName: process.env.FAILED_ORDERS_TABLE_NAME,
        Item: failedOrderItem
    });

    await docClient.send(command);
}

function generateTrackingNumber() {
    return 'TRK' + Date.now() + Math.random().toString(36).substr(2, 5).toUpperCase();
}

function getEstimatedDelivery() {
    const deliveryDate = new Date();
    deliveryDate.setDate(deliveryDate.getDate() + Math.floor(Math.random() * 7) + 1); // 1-7 days
    return deliveryDate.toISOString();
}