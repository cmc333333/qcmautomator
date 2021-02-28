import logging

import typer

from qcmautomator import books, podcasts, watching

app = typer.Typer()
app.add_typer(books.cli, name="books")
app.add_typer(podcasts.cli, name="podcasts")
app.add_typer(watching.cli, name="watching")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    app()
