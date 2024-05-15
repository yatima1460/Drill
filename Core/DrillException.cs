using System.Diagnostics;
using System.Runtime.Serialization;

namespace Drill.Core
{
    [Serializable]
    internal class DrillException : Exception
    {
        public DrillException()
        {
        }

        public DrillException(string? message) : base(message)
        {
            Debug.WriteLine(message);
        }

        public DrillException(string? message, Exception? innerException) : base(message, innerException)
        {
            Debug.WriteLine(message); 
            Debug.WriteLine(innerException);
        }

        protected DrillException(SerializationInfo info, StreamingContext context) : base(info, context)
        {
        }
    }
}