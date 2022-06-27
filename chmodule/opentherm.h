#ifndef OTGW_OPENTHERM_H_
#define OTGW_OPENTHERM_H_

/* IN_MODULE should be defined for modules */
#define IN_MODULE

#include "modules.h"
#include "value.h"
#include "trigger.h"

enum OTDataTypes {
    kReadData = 0,
    kWriteData = 1,
    kInvalidData = 2,
    kReadAck = 4,
    kWriteAck = 5,
    kDataInvalid = 6,
    kUnknownDataID = 7
};

enum StatusCounters {
    kCounterSent,
    kCounterReceived,
    kCounterStopBit,
    kCounterParity,
    kCounterCorrupt,
    kCounterDirection,
    kCounterInvalid,
    kCounterMissing,
    kCounterMismatch,
    kCounterUnexpected,
    kCounterCount	// Must be last
};

enum ThermostatModes {
    kModeOpentherm,
    kModeOff,
    kModeOn
};

enum PowerLevels {
    kPowerLow,
    kPowerMedium,
    kPowerHigh
};

enum PowerStates {
    kPowerIdle,
    kPowerPendingLow,
    kPowerPendingMedium,
    kPowerPendingHigh,
    kPowerWaitMedium,
    kPowerWaitHigh
};

class ModeAttribute;
class TransmitAttribute;
class ReceiveAttribute;
class RespondAttribute;
class ReportAttribute;
class PowerAttribute;
class OTInput;
class OTOutput;
class Transmitter;
class Receiver;
class Float;
class Boolean;

class Opentherm : public Module {
protected:
   OTInput *m_rx;
   OTOutput *m_tx;
   ReceiveAttribute *m_rxbuffer;
   ReportAttribute *m_report;
   int counter[kCounterCount];

public:
   Opentherm(const char *_name, const char *_desc);
   virtual ~Opentherm();
   virtual const char *GetDevice() {};

   unsigned int interface_seq_no;
   Float *m_v_low;
   Float *m_v_high;
   Transmitter *m_xmit;
   Receiver *m_recv;

   virtual bool SendMessage(unsigned msg);
   virtual void LogicalLevels(double v_low, double v_high);
   virtual double GetVoltage(bool active);
   virtual void CreatePinMap();
   virtual void RxEdgeEvent(bool bit);
   virtual void NewRxMessage(unsigned msg);
   virtual void IncrCounter(enum StatusCounters num);
   virtual void ResetCounters();
   virtual std::string SummaryReport() = 0;
   virtual std::string SummaryReport(int count);
   virtual void ReceiveMode(bool b) {};
   virtual unsigned SetParity(unsigned message);
};

class Thermostat : public Opentherm, public TriggerObject {
   TransmitAttribute *m_txbuffer;
   ModeAttribute *m_mode;
   PowerAttribute *m_power;
   Float *m_interval, *m_roomtemp, *m_setpoint;
   guint64 msg_time;
   guint32 request[64] = {};
   int request_count = 0, pointer = 0, msgid = -1, override = 0;
   enum ThermostatModes mode = kModeOpentherm;
   enum PowerStates powerstate = kPowerIdle;

public:
   explicit Thermostat(const char *);
   ~Thermostat();
   const char *GetDevice();
   virtual void AddMessage(unsigned int);
   virtual void NewRxMessage(unsigned msg);
   virtual bool SendMessage(unsigned msg);
   void SetMode(enum ThermostatModes);
   enum ThermostatModes GetMode();
   void SetPower(enum PowerLevels);
   enum PowerLevels GetPower();
   void ScheduleMessage(double delay = 0.0);
   bool SmartPower(enum PowerLevels newLevel);
   virtual std::string SummaryReport();
   void callback() override;

   static Module *construct(const char *new_name);
};

class Boiler : public Opentherm, public TriggerObject {
   RespondAttribute *m_responder;
   guint64 mode_time;
   guint32 response[256] = {};
   guint32 message;

public:
   explicit Boiler(const char *);
   ~Boiler();
   const char *GetDevice();
   void SetResponse(unsigned msg);
   void NewRxMessage(unsigned msg);
   virtual void ReceiveMode(bool b) override;
   virtual std::string SummaryReport();
   void callback() override;

   static Module *construct(const char *new_name);
};

#endif //  OTGW_OPENTHERM_H_
