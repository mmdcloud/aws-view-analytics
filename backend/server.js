// server.js
const express = require('express');
const { KinesisClient, PutRecordCommand } = require('@aws-sdk/client-kinesis');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Server-side client will use EC2 instance profile credentials automatically
const client = new KinesisClient({ region: 'us-east-1' });

app.post('/api/kinesis', async (req, res) => {
    try {
        const { payload, timestamp } = req.body;

        const params = {
            StreamName: 'view-analytics-stream',
            Data: new TextEncoder().encode(JSON.stringify({
                payload,
                timestamp: timestamp || new Date().toISOString()
            })),
            PartitionKey: 'partition-' + Date.now()
        };

        const command = new PutRecordCommand(params);
        const response = await client.send(command);
        console.log(response);
        res.json({ success: true, sequenceNumber: response.SequenceNumber });
    } catch (error) {
        console.error('Error sending to Kinesis:', error);
        res.status(500).json({ error: error.message });
    }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    console.log(`Proxy server running on port ${PORT}`);
});