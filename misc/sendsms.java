public class SmsActivity extends Activity implements View.OnClickListener
{
    private static final String SENT = "SMS_SENT";
    private static final String DELIVERED = "SMS_DELIVERED";
    private static final String EXTRA_NAME = "name";
    private static final String EXTRA_NUMBER = "number";

    private static final String[] names = new String[] { "Name1", "Name2", "Name3", "Name4" };
    private static final String[] numbers = new String[] { "1234567890", "1234567890", "1234567890", "1234567890" };

    SmsManager smsMgr;
    IntentFilter filter;

    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_sms);

        ((Button) findViewById(R.id.button1)).setOnClickListener(this);

        smsMgr = SmsManager.getDefault();

        filter = new IntentFilter(SENT);
        filter.addAction(DELIVERED);
    }

    @Override
    protected void onResume()
    {
        super.onResume();
        registerReceiver(receiver, filter);
    }

    @Override
    protected void onPause()
    {
        super.onPause();
        unregisterReceiver(receiver);
    }

    public void onClick(View v)
    {
        for (int i = 0; i < names.length; i++)
        {
            sendText(numbers[i], names[i], i);
        }
    }

    private void sendText(String conNumber, String conName, int requestCode)
    {
        Intent sentIntent = new Intent(SENT);
        Intent deliveredIntent = new Intent(DELIVERED);

        sentIntent.putExtra(EXTRA_NUMBER, conNumber);
        sentIntent.putExtra(EXTRA_NAME, conName);

        PendingIntent sentPI = PendingIntent.getBroadcast(this, requestCode, sentIntent, 0);
        PendingIntent deliveredPI = PendingIntent.getBroadcast(this, requestCode, deliveredIntent, 0);

        smsMgr.sendTextMessage(conNumber, null, "Hello", sentPI, deliveredPI);
    }

    private BroadcastReceiver receiver = new BroadcastReceiver()
    {
        @Override
        public void onReceive(Context context, Intent intent)
        {
            if (SENT.equals(intent.getAction()))
            {
                String name = intent.getStringExtra("name");
                String number = intent.getStringExtra("number");

                switch (getResultCode())
                {
                    case Activity.RESULT_OK:
                        toastShort("SMS sent to " + name + " & " + number);
                        break;

                    case SmsManager.RESULT_ERROR_GENERIC_FAILURE:
                        toastShort("Generic failure");
                        break;

                    case SmsManager.RESULT_ERROR_NO_SERVICE:
                        toastShort("No service");
                        break;

                    case SmsManager.RESULT_ERROR_NULL_PDU:
                        toastShort("Null PDU");
                        break;

                    case SmsManager.RESULT_ERROR_RADIO_OFF:
                        toastShort("Radio off");
                        break;
                }
            }
            else if (DELIVERED.equals(intent.getAction()))
            {
                switch (getResultCode())
                {
                    case Activity.RESULT_OK:
                        toastShort("SMS delivered");
                        break;

                    case Activity.RESULT_CANCELED:
                        toastShort("SMS not delivered");
                        break;
                }
            }
        }
    };

    private void toastShort(String msg)
    {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }   
}