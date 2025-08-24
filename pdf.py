from fpdf import FPDF

# Load the contents of the main.c file
with open("core/src/main.c", "r") as file:
    c_code = file.read()

# Initialize PDF
pdf = FPDF()
pdf.set_auto_page_break(auto=True, margin=15)
pdf.add_page()
pdf.set_font("Courier", size=10)

# Split the code into lines and add to PDF
for line in c_code.splitlines():
    pdf.cell(0, 5, txt=line, ln=True)

# Save the PDF
output_path = "main_c_code.pdf"
pdf.output(output_path)


