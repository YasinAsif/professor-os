import ssl
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from app.core.config import get_settings

def test_smtp():
    settings = get_settings()
    print("Testing SMTP connection with settings:")
    print(f"Host: {settings.SMTP_HOST}")
    print(f"User: {settings.SMTP_USER}")
    print(f"From: {settings.EMAIL_FROM}")
    
    to = "yasif9155@gmail.com"
    subject = "ProfessorOS SMTP Diagnostics"
    html = "<h3>SMTP connection test successful!</h3>"
    
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = f"ProfessorOS <{settings.EMAIL_FROM}>"
    msg["To"] = to
    msg.attach(MIMEText(html, "html"))
    
    context = ssl.create_default_context()
    try:
        print("Connecting to SMTP_SSL on port 465...")
        with smtplib.SMTP_SSL(settings.SMTP_HOST, 465, context=context, timeout=15) as server:
            print("Logging in...")
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            print("Sending test email...")
            server.sendmail(settings.SMTP_USER, to, msg.as_string())
            print("SUCCESS! Test email sent successfully.")
    except Exception as e:
        print(f"FAILED: {e}")

if __name__ == "__main__":
    test_smtp()
