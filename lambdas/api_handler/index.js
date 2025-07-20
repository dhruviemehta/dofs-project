const { SFNClient, StartExecutionCommand } = require('@aws-sdk/client-sfn');
const { v4: uuidv4 } = require('uuid');

// AWS SDK will automatically detect the region from the Lambda execution environment
const sfnClient = new SFNClient({ region: process.env.AWS_REGION });

exports.handler = async (event) => {
    console.log('API Handler - Received event:', JSON.stringify(event, null, 2));

    try {
        // Parse the request body
        let body;
        try {
            body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        } catch (parseError) {
            console.error('Failed to parse request body:', parseError);
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Invalid JSON in request body',
                    message: parseError.message
                })
            };
        }

        // Validate required fields
        if (!body.customerId || !body.productId || !body.quantity || !body.price) {
            return {
                statusCode: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                body: JSON.stringify({
                    error: 'Missing required fields',
                    required: ['customerId', 'productId', 'quantity', 'price']
                })
            };
        }

        // Generate order ID and prepare order data
        const orderId = uuidv4();
        const orderData = {
            orderId,
            customerId: body.customerId,
            productId: body.productId,
            quantity: parseInt(body.quantity),
            price: parseFloat(body.price),
            status: 'PENDING',
            timestamp: new Date().toISOString(),
            metadata: body.metadata || {}
        };

        console.log('Starting Step Function execution for order:', orderId);

        // Start Step Function execution
        const stepFunctionParams = {
            stateMachineArn: process.env.STEP_FUNCTION_ARN,
            name: `order-${orderId}-${Date.now()}`,
            input: JSON.stringify(orderData)
        };

        const command = new StartExecutionCommand(stepFunctionParams);
        const result = await sfnClient.send(command);

        console.log('Step Function execution started:', result.executionArn);

        return {
            statusCode: 202,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                orderId,
                status: 'ACCEPTED',
                executionArn: result.executionArn,
                message: 'Order received and processing started'
            })
        };

    } catch (error) {
        console.error('Error in API Handler:', error);

        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: 'Internal server error',
                message: error.message
            })
        };
    }
};