const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

// AWS SDK will automatically detect the region from the Lambda execution environment
const dynamoClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(dynamoClient);
const sqsClient = new SQSClient({});

exports.handler = async (event) => {
    console.log('Order Storage - Received event:', JSON.stringify(event, null, 2));

    try {
        const orderData = event;

        // Prepare order item for DynamoDB
        const orderItem = {
            order_id: orderData.orderId,
            customer_id: orderData.customerId,
            product_id: orderData.productId,
            quantity: orderData.quantity,
            price: orderData.price,
            total_amount: orderData.totalAmount,
            status: 'PROCESSING',
            created_at: orderData.timestamp,
            updated_at: new Date().toISOString(),
            validation_status: orderData.validationStatus,
            metadata: orderData.metadata || {}
        };

        console.log('Storing order in DynamoDB:', orderItem.order_id);

        // Store order in DynamoDB
        const putCommand = new PutCommand({
            TableName: process.env.ORDERS_TABLE_NAME,
            Item: orderItem,
            ConditionExpression: 'attribute_not_exists(order_id)' // Prevent duplicates
        });

        await docClient.send(putCommand);

        console.log('Order stored successfully, sending to SQS queue');

        // Send message to SQS for fulfillment processing
        const sqsMessage = {
            orderId: orderData.orderId,
            customerId: orderData.customerId,
            productId: orderData.productId,
            quantity: orderData.quantity,
            price: orderData.price,
            totalAmount: orderData.totalAmount,
            timestamp: new Date().toISOString(),
            source: 'order_storage'
        };

        const sendMessageCommand = new SendMessageCommand({
            QueueUrl: process.env.ORDER_QUEUE_URL,
            MessageBody: JSON.stringify(sqsMessage),
            MessageAttributes: {
                'order_id': {
                    DataType: 'String',
                    StringValue: orderData.orderId
                },
                'customer_id': {
                    DataType: 'String',
                    StringValue: orderData.customerId
                }
            }
        });

        const sqsResult = await sqsClient.send(sendMessageCommand);

        console.log('Message sent to SQS:', sqsResult.MessageId);

        // Return success response for Step Functions
        return {
            orderId: orderData.orderId,
            status: 'STORED',
            dynamodbResult: 'SUCCESS',
            sqsMessageId: sqsResult.MessageId,
            timestamp: new Date().toISOString()
        };

    } catch (error) {
        console.error('Error in Order Storage:', error);

        // For Step Functions error handling
        const storageError = {
            error: 'STORAGE_FAILED',
            message: error.message,
            orderData: event,
            timestamp: new Date().toISOString()
        };

        throw storageError;
    }
};